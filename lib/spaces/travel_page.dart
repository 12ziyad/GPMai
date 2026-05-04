// lib/spaces/travel_page.dart
// Travel space: clean UI, trips (folders), per-tool question forms, editable & persistent outputs.
// Uses your existing SqlChatStore + GPMaiBrain + ChatPage. No new packages beyond ones already used.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui; // for ui.Rect

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard, ClipboardData
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../services/gpmai_brain.dart';
import '../services/sql_chat_store.dart';
import '../widgets/markdown_bubble.dart';
import '../screens/chat_page.dart' show ChatPage, AttachmentSeed;
import 'dart:typed_data';

const _electricBlue = Color(0xFF00B8FF);

/* ──────────────────────────────────────────────────────────────────────────
  TRAVEL PAGE
────────────────────────────────────────────────────────────────────────── */

class TravelPage extends StatefulWidget {
  final String userId;
  const TravelPage({super.key, required this.userId});

  @override
  State<TravelPage> createState() => _TravelPageState();
}

class _TravelPageState extends State<TravelPage> with TickerProviderStateMixin {
  // Inputs
  final TextEditingController _from = TextEditingController();
  final TextEditingController _dest = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  DateTimeRange? _range;
  int _travelers = 2;

  // budget UI: tap-to-enter number (no slider overflow)
  double _budgetPerPerson = 30000; // INR
  final Set<String> _interests = {'Food', 'Nature', 'Shopping'};

  // Plan
  bool _generating = false;
  String _planMd = '';
  String _lastAiPlan = '';

  // Trips (folders)
  final _tripStore = _TripStore();
  _Trip? _activeTrip;

  // Quick suggestions
  final _suggested = const [
    'Bali', 'Singapore', 'Bangkok', 'Goa', 'Dubai', 'Kuala Lumpur', 'Sri Lanka', 'Paris'
  ];

  // Lightweight KV (uses SqlChatStore under the hood)
  final _kv = _LocalStore('__TRAVEL_LOCAL_STORE__');

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final activeId = await _kv.load('active_trip_id');
    if (activeId != null && activeId.isNotEmpty) {
      final t = await _tripStore.getById(activeId);
      _activeTrip = t;
      final p = await _tripStore.loadValue(activeId, 'plan_md');
      if (mounted && p != null) _planMd = p;
      final ai = await _tripStore.loadValue(activeId, 'ai_plan_md');
      if (ai != null) _lastAiPlan = ai;
    } else {
      final p = await _kv.load('last_plan_md');
      if (mounted && p != null) _planMd = p;
      final ai = await _kv.load('last_ai_plan_md');
      if (ai != null) _lastAiPlan = ai;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _from.dispose();
    _dest.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(_activeTrip == null ? 'Travel' : 'Travel — ${_activeTrip!.title}'),
        actions: [
          // SAVE (blue) — saves to the active folder
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_rounded, color: _electricBlue),
            onPressed: _savePlanLocally,
          ),
          IconButton(
            tooltip: 'Trips',
            icon: const Icon(Icons.folder_rounded),
            onPressed: _openTrips,
          ),
          IconButton(
            tooltip: 'Open as Chat',
            onPressed: _openAsChatPrompt,
            icon: const Icon(Icons.support_agent_rounded),
          ),
        ],
      ),

      // Fixed, larger floating + button for quick actions
      floatingActionButton: FloatingActionButton(
        heroTag: 'travel_plus_global',
        backgroundColor: _electricBlue,
        foregroundColor: Colors.black,
        onPressed: _showQuickActions,
        child: const Icon(Icons.add, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 6),
            _Tabs(),
            Expanded(
              child: TabBarView(
                children: [
                  // PLAN
                  ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                    children: [
                      const _SectionTitle('Trip Basics'),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // From & Destination
                            _RouteFields(
                              fromController: _from,
                              toController: _dest,
                              onPickSuggestion: (v) => setState(() => _dest.text = v),
                              suggestions: _suggested,
                            ),
                            const SizedBox(height: 10),
                            _DateRow(
                              label: _range == null
                                  ? 'Pick start and end'
                                  : '${_d(_range!.start)} → ${_d(_range!.end)}  •  ${_nights(_range!)} nights',
                              onTap: _pickDates,
                            ),
                            const SizedBox(height: 10),
                            // Travelers + Budget (safe, no overflow)
                            _TravelersBudgetRow(
                              travelers: _travelers,
                              budgetPer: _budgetPerPerson,
                              onTravelers: (v) => setState(() => _travelers = v),
                              onBudget: (v) => setState(() => _budgetPerPerson = v),
                            ),
                            const SizedBox(height: 10),
                            _InterestChips(
                              values: _interests,
                              onToggle: (v) => setState(() {
                                if (_interests.contains(v)) {
                                  _interests.remove(v);
                                } else {
                                  _interests.add(v);
                                }
                              }),
                            ),
                            const SizedBox(height: 10),

                            // Notes (global FAB handles quick actions now)
                            _NotesField(controller: _notes),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _SectionTitle('Plan'),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(
                                child: _PrimaryButton(
                                  label: _generating ? 'Generating…' : 'Generate Itinerary',
                                  icon: _generating
                                      ? Icons.hourglass_bottom_rounded
                                      : Icons.travel_explore_rounded,
                                  onTap: _generating ? null : _generatePlan,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PrimaryButton(
                                  label: 'Customize',
                                  icon: Icons.tune_rounded,
                                  onTap: _planMd.isEmpty ? null : _openCustomize,
                                ),
                              ),
                            ]),
                            if (_planMd.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              MarkdownBubble(text: _planMd, textColor: textColor, linkColor: _electricBlue),
                              const SizedBox(height: 12),
                              Wrap(spacing: 10, runSpacing: 10, children: [
                                _PillButton(
                                  icon: Icons.edit_rounded,
                                  label: 'Edit',
                                  onTap: () async {
                                    final edited = await _editText(context, _planMd, title: 'Edit Plan');
                                    if (edited == null) return;
                                    setState(() => _planMd = edited);
                                    await _savePlanLocally();
                                  },
                                ),
                                _PillButton(
                                  icon: Icons.copy_rounded,
                                  label: 'Copy',
                                  onTap: () async {
                                    await Clipboard.setData(ClipboardData(text: _planMd));
                                    _toast('Copied');
                                  },
                                ),
                                _PillButton(
                                  icon: Icons.save_rounded,
                                  label: 'Save',
                                  onTap: _savePlanLocally,
                                ),
                                _PillButton(
                                  icon: Icons.chat_bubble_rounded,
                                  label: 'Save as Chat',
                                  onTap: _savePlanAsChat,
                                ),
                                _PillButton(
                                  icon: Icons.picture_as_pdf_rounded,
                                  label: 'Export PDF',
                                  onTap: _exportPlanPdf,
                                ),
                                _PillButton(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Delete',
                                  onTap: () => setState(() => _planMd = ''),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // TOOLS
                  _ToolsGrid(
                    userId: widget.userId,
                    composeBrief: _composeBrief,
                    destGetter: () => _dest.text.trim(),
                    activeTrip: _activeTrip,
                    onTripUpdated: (t) async {
                      _activeTrip = t;
                      await _kv.save('active_trip_id', t.id);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── Logic ───────────────────────

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final nextYear = DateTime(now.year + 2);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: nextYear,
      saveText: 'Select',
      helpText: 'Select your travel dates',
    );
    if (!mounted) return;
    setState(() => _range = picked);
  }

  String _composeBrief() {
    final from = _from.text.trim().isEmpty ? 'Unknown origin' : _from.text.trim();
    final dest = _dest.text.trim().isEmpty ? 'Unknown destination' : _dest.text.trim();
    final dates = _range == null ? 'Flexible dates' : '${_d(_range!.start)} to ${_d(_range!.end)} (${_nights(_range!)} nights)';
    final crowd = '$_travelers traveler${_travelers > 1 ? 's' : ''}';
    final budget = '₹${_budgetPerPerson.round()} per person (approx.)';
    final interests = _interests.isEmpty ? 'General' : _interests.join(', ');
    final extra = _notes.text.trim().isEmpty ? 'None' : _notes.text.trim();
    return '''
From: $from
To: $dest
Dates: $dates
People: $crowd
Budget: $budget
Interests: $interests
Notes: $extra
'''.trim();
  }

  Future<void> _ensureActiveTrip() async {
    if (_activeTrip != null) return;
    final t = _Trip(
      id: 'trip_${DateTime.now().microsecondsSinceEpoch}',
      title: _dest.text.trim().isEmpty ? 'New Trip' : _dest.text.trim(),
      start: _range?.start,
      end: _range?.end,
    );
    await _tripStore.upsert(t);
    await _kv.save('active_trip_id', t.id);
    setState(() => _activeTrip = t);
  }

  Future<void> _generatePlan() async {
    final dest = _dest.text.trim();
    if (dest.isEmpty) {
      _toast('Add a destination');
      return;
    }
    await _ensureActiveTrip();

    setState(() {
      _generating = true;
      _planMd = '';
    });

    final daysRaw = _range == null ? 4 : (_nights(_range!) + 1);
    final int days = daysRaw < 3 ? 3 : (daysRaw > 7 ? 7 : daysRaw);
    final brief = _composeBrief();

    final prompt = '''
Plan a ${days}-day **travel itinerary** for the details below. Output in crisp Markdown sections. Answer in **English only**.

# Quick Snapshot
- Best areas to stay (3)
- Average costs (INR)
- Weather & what to expect

# Day-by-Day Plan
- Morning / Afternoon / Evening with times
- Specific places (with short why)
- Commute hints (walk/metro/ride times)

# Food & Nightlife
- Must-try food + 4–6 restaurants/streets
- Nightlife options (safe areas, timings, entry fees if common)

# Budget (INR)
- Flights (approx from **the origin city**), stay, daily spend, activities
- Show **Per Person** and **Total**

# Local Tips
- Getting around (metro cards, passes)
- Etiquette, tipping, SIM/eSIM options, power plug
- Safety & common scams to avoid

# Free / Low-Cost
- At least 6 ideas

Personal details:
$brief

Use short sentences. Avoid fluff. Keep it practical and specific.
''';

    String out;
    try {
      out = await GPMaiBrain.send(prompt);
    } catch (e) {
      out = '[Error] $e';
    }
    out = _stripMood(out).trim();

    if (!mounted) return;
    setState(() {
      _planMd = out;
      _lastAiPlan = out;
      _generating = false;
    });
    await _savePlanLocally();
  }

  Future<void> _savePlanLocally() async {
    if (_activeTrip != null) {
      await _tripStore.saveValue(_activeTrip!.id, 'plan_md', _planMd);
      await _tripStore.saveValue(_activeTrip!.id, 'ai_plan_md', _lastAiPlan);
    } else {
      await _kv.save('last_plan_md', _planMd);
      await _kv.save('last_ai_plan_md', _lastAiPlan);
    }
    _toast('Saved');
  }

  Future<void> _refinePlan() async {
    if (_planMd.isEmpty) {
      _toast('Generate a plan first');
      return;
    }
    setState(() => _generating = true);
    await _ensureActiveTrip();

    final brief = _composeBrief();
    final refine = '''
Improve the existing plan below to be tighter and more realistic.
- Keep same structure.
- Add opening/closing hours where useful.
- Add commute durations where obvious (~ mins).
- Keep prices in INR, approximate ranges.
- Answer in **English only**.

Trip details:
$brief

Plan to refine:
$_planMd
''';

    String out;
    try {
      out = await GPMaiBrain.send(refine);
    } catch (e) {
      out = '[Error] $e';
    }
    out = _stripMood(out).trim();

    if (!mounted) return;
    setState(() {
      _planMd = out;
      _generating = false;
    });
    await _savePlanLocally();
  }

  Future<void> _openCustomize() async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _CustomizePlanPage(
          original: _lastAiPlan.isEmpty ? _planMd : _lastAiPlan,
          current: _planMd,
          onRegenerate: _regenerateSelection,
        ),
      ),
    );
    if (edited == null) return;
    if (!mounted) return;
    setState(() => _planMd = edited);
    await _savePlanLocally();
  }

  Future<String> _regenerateSelection(String selection, String instructions) async {
    final brief = _composeBrief();
    final prompt = '''
Rewrite ONLY the following selection from a travel plan.

Guidelines:
- Follow these user instructions: "$instructions".
- Keep the rest of the plan untouched.
- Keep Markdown style consistent (no top-level title changes).
- Prices in INR where applicable.
- Answer in **English only**.

Trip details:
$brief

Selection to rewrite:
$selection
''';
    try {
      final r = await GPMaiBrain.send(prompt);
      return _stripMood(r).trim();
    } catch (e) {
      return '[Error] $e';
    }
  }

  Future<void> _savePlanAsChat() async {
    if (_planMd.isEmpty) {
      _toast('Nothing to save');
      return;
    }
    final store = SqlChatStore();
    final title = _activeTrip?.title ?? (_dest.text.trim().isEmpty ? 'Trip Plan' : 'Trip: ${_dest.text.trim()}');
    final chatId = await store.createChat(
      name: title,
      preset: {'kind': 'tool', 'id': 'travel'},
    );

    final userSeed = 'Trip details (for reference):\n${_composeBrief()}';
    await store.addMessage(chatId: chatId, role: 'user', text: userSeed);
    await store.addMessage(chatId: chatId, role: 'gpm', text: _planMd);

    if (!mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, a1, __) => FadeTransition(
        opacity: a1,
        child: ChatPage(
          userId: widget.userId,
          chatId: chatId,
          chatName: title,
        ),
      ),
    ));
  }

  Future<void> _openAsChatPrompt() async {
    final store = SqlChatStore();
    final chatId = await store.createChat(
      name: _dest.text.trim().isEmpty ? 'Travel Planner' : 'Plan ${_dest.text.trim()}',
      preset: {'kind': 'tool', 'id': 'travel'},
    );

    final seed = '''
Create a full, specific itinerary based on:

${_composeBrief()}

Return compact, actionable Markdown with: Quick Snapshot, Day-by-Day, Food & Nightlife, Budget (INR), Local Tips, Free/Low-Cost. Answer in **English only**.
'''.trim();

    if (!mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, a1, __) => FadeTransition(
        opacity: a1,
        child: ChatPage(
          userId: widget.userId,
          chatId: chatId,
          chatName: 'Travel Planner',
          seedUserText: seed,
        ),
      ),
    ));
  }

  Future<void> _openTrips() async {
    final res = await Navigator.push<_TripAction>(
      context,
      MaterialPageRoute(
        builder: (_) => _TripsManagerPage(
          currentDraft: _TripDraft(
            dest: _dest.text.trim(),
            range: _range,
          ),
        ),
      ),
    );
    if (res == null) return;

    if (res.kind == _TripActionKind.select && res.trip != null) {
      _activeTrip = res.trip;
      await _kv.save('active_trip_id', _activeTrip!.id);
      final p = await _tripStore.loadValue(_activeTrip!.id, 'plan_md');
      if (mounted) setState(() => _planMd = p ?? '');
    } else if (res.kind == _TripActionKind.created && res.trip != null) {
      _activeTrip = res.trip;
      await _kv.save('active_trip_id', _activeTrip!.id);
      if (mounted) setState(() {});
    } else if (res.kind == _TripActionKind.deleted && _activeTrip != null && res.trip != null) {
      if (_activeTrip!.id == res.trip!.id) {
        _activeTrip = null;
        await _kv.save('active_trip_id', '');
        if (mounted) setState(() => _planMd = '');
      }
    }
  }

  // + button helpers
  void _showQuickActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.create_new_folder_rounded),
            title: const Text('Create new page'),
            onTap: () {
              Navigator.pop(context);
              _createFreshPage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded),
            title: const Text('Export plan as PDF'),
            onTap: () {
              Navigator.pop(context);
              _exportPlanPdf();
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Ask in chat'),
            onTap: () {
              Navigator.pop(context);
              _openAsChatPrompt();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _createFreshPage() async {
    final t = _Trip(
      id: 'trip_${DateTime.now().microsecondsSinceEpoch}',
      title: 'New Trip',
    );
    await _tripStore.upsert(t);
    await _kv.save('active_trip_id', t.id);
    setState(() {
      _activeTrip = t;
      _from.clear();
      _dest.clear();
      _notes.clear();
      _range = null;
      _travelers = 2;
      _budgetPerPerson = 30000;
      _interests
        ..clear()
        ..addAll(['Food', 'Nature', 'Shopping']);
      _planMd = '';
      _lastAiPlan = '';
    });
  }

  Future<void> _exportPlanPdf() async {
    if (_planMd.trim().isEmpty) {
      _toast('Generate a plan first');
      return;
    }
    final title = _activeTrip?.title.isNotEmpty == true
        ? 'Trip Plan — ${_activeTrip!.title}'
        : 'Trip Plan';

    final doc = sf.PdfDocument();
    final page = doc.pages.add();
    final sz = page.getClientSize();

    final titleText = sf.PdfTextElement(
      text: title,
      font: sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        18,
        style: sf.PdfFontStyle.bold,
      ),
    );
    titleText.draw(page: page, bounds: ui.Rect.fromLTWH(0, 0, sz.width, 24));

    final bodyText = sf.PdfTextElement(
      text: _planMd,
      font: sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
    );
    bodyText.draw(
      page: page,
      bounds: ui.Rect.fromLTWH(0, 28, sz.width, sz.height - 28),
    );

    final raw = await doc.save(); // raw is List<int>
    doc.dispose();

    final bytes = Uint8List.fromList(raw); // <-- convert to Uint8List

    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'trip_plan.pdf', mimeType: 'application/pdf')],
      subject: title,
      text: 'Trip plan PDF',
    );
  }

  // helpers
  static String _d(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  static String _two(int n) => n < 10 ? '0$n' : '$n';
  static int _nights(DateTimeRange r) => r.duration.inDays;
  static String _stripMood(String s) =>
      s.replaceAll(RegExp(r'\\[mood:[^\\]]*\\]', caseSensitive: false), '');

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* ───────────────────────── TOOLS GRID ───────────────────────── */

class _ToolsGrid extends StatelessWidget {
  final String userId;
  final String Function() composeBrief;
  final String Function() destGetter;
  final _Trip? activeTrip;
  final ValueChanged<_Trip> onTripUpdated;

  const _ToolsGrid({
    required this.userId,
    required this.composeBrief,
    required this.destGetter,
    required this.activeTrip,
    required this.onTripUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final items = const [
      _Tool('packing', 'Packing List', Icons.luggage_rounded),
      _Tool('visa', 'Visa & Docs', Icons.assignment_turned_in_rounded),
      _Tool('safety', 'Safety & Scams', Icons.shield_rounded),
      _Tool('budget', 'Budget Breakdown', Icons.account_balance_wallet_rounded),
      _Tool('besttime', 'Best Time / Weather', Icons.wb_sunny_rounded),
      _Tool('transport', 'Getting Around', Icons.directions_bus_filled_rounded),
      _Tool('sim', 'SIM / eSIM Tips', Icons.sim_card_rounded),
      _Tool('food', 'Must-Try Foods', Icons.restaurant_menu_rounded),
      _Tool('spots', 'Photo Spots', Icons.camera_alt_rounded),
      _Tool('daytrips', 'Day Trips Nearby', Icons.map_rounded),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      children: [
        const _SectionTitle('Quick Tools'),
        _Card(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisExtent: 112, crossAxisSpacing: 12, mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) {
              final it = items[i];
              return _ToolTile(
                tool: it,
                onTap: () async {
                  final dest = destGetter();
                  final trip = activeTrip;
                  if (it.id == 'packing') {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _PackingListPage(
                        destHint: dest,
                        brief: composeBrief(),
                        trip: trip,
                      ),
                    ));
                    return;
                  }
                  if (it.id == 'visa') {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _VisaDocsPage(userId: userId, trip: trip),
                    ));
                    return;
                  }
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _SmartToolPage(
                      toolId: it.id,
                      title: it.title,
                      destHint: dest,
                      brief: composeBrief(),
                      trip: trip,
                    ),
                  ));
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────── TRAVELERS + BUDGET (no overflow) ───────────────────────── */

class _TravelersBudgetRow extends StatelessWidget {
  final int travelers;
  final double budgetPer;
  final ValueChanged<int> onTravelers;
  final ValueChanged<double> onBudget;

  const _TravelersBudgetRow({
    required this.travelers,
    required this.budgetPer,
    required this.onTravelers,
    required this.onBudget,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.onSurface.withOpacity(.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // travelers stepper
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0x2A00B8FF),
                child: Icon(Icons.group_rounded, color: _electricBlue, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Travelers', style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              _RoundIcon(
                onTap: travelers > 1 ? () => onTravelers(travelers - 1) : null,
                icon: Icons.remove_rounded,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('$travelers', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              _RoundIcon(onTap: () => onTravelers(travelers + 1), icon: Icons.add_rounded),
            ],
          ),
          const SizedBox(height: 10),

          // budget + total
          Row(
            children: [
              Flexible(
                child: InkWell(
                  onTap: () async {
                    final v = await _pickBudget(context, budgetPer);
                    if (v != null) onBudget(v);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _electricBlue,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Budget per person: ₹${budgetPer.round()}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('Total ≈ ₹${(budgetPer * travelers).round()}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Future<double?> _pickBudget(BuildContext context, double current) async {
    final c = TextEditingController(text: current.round().toString());
    return showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Budget per person (INR)'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. 30000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final n = double.tryParse(c.text.trim());
              Navigator.pop(context, n);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── ORIGIN/DESTINATION FIELDS ───────────────────────── */

class _RouteFields extends StatelessWidget {
  final TextEditingController fromController;
  final TextEditingController toController;
  final void Function(String) onPickSuggestion;
  final List<String> suggestions;

  const _RouteFields({
    required this.fromController,
    required this.toController,
    required this.onPickSuggestion,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: fromController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'From',
                  hintText: 'e.g., Mumbai, Delhi…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: toController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  hintText: 'e.g., Singapore, Bali…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((s) {
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onPickSuggestion(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.onSurface.withOpacity(.18)),
                ),
                child: Text(s),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/* ───────────────────────── PACKING LIST PAGE ───────────────────────── */

class _PackingListPage extends StatefulWidget {
  final String destHint;
  final String brief;
  final _Trip? trip;
  const _PackingListPage({required this.destHint, required this.brief, required this.trip});

  @override
  State<_PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends State<_PackingListPage> {
  final _notesCtrl = TextEditingController();
  String _organizedMd = '';
  bool _busy = false;
  late final _TripStore _ts = _TripStore();

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final kNotes = _k('packing_notes');
    final kOrg = _k('packing_organized');
    _notesCtrl.text = (await _ts.loadValue(widget.trip?.id, kNotes)) ?? '';
    _organizedMd = (await _ts.loadValue(widget.trip?.id, kOrg)) ?? '';
    if (mounted) setState(() {});
  }

  String _k(String base) => base; // namespaced by trip id inside TripStore

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _seedFromAI() async {
    setState(() => _busy = true);
    final ask = '''
Create a compact **packing checklist** tailored to:

${widget.brief}

Group by: Essentials, Clothing, Footwear, Toiletries, Tech, Health/Safety, Documents, Optional.
Keep bullets short. Add plug type and baggage notes for flights.
Answer in **English only**.
''';
    try {
      final out = await GPMaiBrain.send(ask);
      setState(() => _organizedMd = _stripMood(out).trim());
      await _ts.saveValue(widget.trip?.id, _k('packing_organized'), _organizedMd);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _organizeFreeform() async {
    final raw = _notesCtrl.text.trim();
    if (raw.isEmpty) {
      _snack('Type items first');
      return;
    }
    setState(() => _busy = true);
    final ask = '''
You will receive a messy list of things a traveler wants to bring.
Organize them into neat Markdown with headings:
- Essentials
- Clothing
- Footwear
- Toiletries
- Tech
- Health/Safety
- Documents
- Optional / Nice-to-have
Answer in **English only**.

Input list (one per line):
$raw
''';
    try {
      final out = await GPMaiBrain.send(ask);
      setState(() => _organizedMd = _stripMood(out).trim());
      await _ts.saveValue(widget.trip?.id, _k('packing_organized'), _organizedMd);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(title: const Text('Packing List'), actions: [
        IconButton(
          tooltip: 'Save',
          icon: const Icon(Icons.save_rounded),
          onPressed: () async {
            await _ts.saveValue(widget.trip?.id, _k('packing_notes'), _notesCtrl.text);
            await _ts.saveValue(widget.trip?.id, _k('packing_organized'), _organizedMd);
            _snack('Saved');
          },
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            setState(() {
              _notesCtrl.clear();
              _organizedMd = '';
            });
            await _ts.saveValue(widget.trip?.id, _k('packing_notes'), '');
            await _ts.saveValue(widget.trip?.id, _k('packing_organized'), '');
            _snack('Cleared');
          },
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Your Notes', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'Type everything you plan to bring… One item per line is easiest.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _PrimaryButton(
                      label: _busy ? 'Working…' : 'Organize List',
                      icon: Icons.auto_awesome_rounded,
                      onTap: _busy ? null : _organizeFreeform,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PrimaryButton(
                      label: _busy ? 'Working…' : 'Generate with AI',
                      icon: Icons.lightbulb_rounded,
                      onTap: _busy ? null : _seedFromAI,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Drop or type anything here — I’ll sort it for you.',
                    style: TextStyle(color: isLight ? Colors.black54 : Colors.white60),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_organizedMd.isNotEmpty)
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.luggage_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    const Text('Organized Packing List', style: TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  MarkdownBubble(text: _organizedMd, textColor: isLight ? Colors.black87 : Colors.white, linkColor: _electricBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  static String _stripMood(String s) =>
      s.replaceAll(RegExp(r'\\[mood:[^\\]]*\\]', caseSensitive: false), '');
}

/* ───────────────────────── VISA & DOCS PAGE ───────────────────────── */

class _VisaDocsPage extends StatefulWidget {
  final String userId;
  final _Trip? trip;
  const _VisaDocsPage({required this.userId, required this.trip});

  @override
  State<_VisaDocsPage> createState() => _VisaDocsPageState();
}

class _VisaDocsPageState extends State<_VisaDocsPage> {
  final _search = TextEditingController();
  final _picker = ImagePicker();
  final _ts = _TripStore();

  List<_DocItem> _docs = [];
  final Set<String> _selected = {};

  String get _keyIndex => 'docs_index';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final s = await _ts.loadValue(widget.trip?.id, _keyIndex);
    if (s != null && s.isNotEmpty) {
      try {
        final arr = (jsonDecode(s) as List).cast<Map>();
        _docs = arr.map((m) => _DocItem.fromJson(Map<String, dynamic>.from(m))).toList();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _persist() async {
    final s = jsonEncode(_docs.map((e) => e.toJson()).toList());
    await _ts.saveValue(widget.trip?.id, _keyIndex, s);
  }

  Future<void> _addFromCamera() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x == null) return;
      final f = File(x.path);
      final name = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      _docs.add(_DocItem(name: name, path: f.path, mime: 'image/jpeg', ts: DateTime.now().millisecondsSinceEpoch));
      await _persist();
      if (mounted) setState(() {});
    } catch (e) {
      _snack('Camera error: $e');
    }
  }

  Future<void> _addFromFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (res == null) return;
      for (final f in res.files) {
        if (f.path == null) continue;
        final mime = _guessMime(f.name.toLowerCase());
        _docs.add(_DocItem(name: f.name, path: f.path!, mime: mime, ts: DateTime.now().millisecondsSinceEpoch));
      }
      await _persist();
      if (mounted) setState(() {});
    } catch (e) {
      _snack('Pick error: $e');
    }
  }

  String _guessMime(String name) {
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  Future<AttachmentSeed?> _buildSeed(_DocItem d) async {
    try {
      final bytes = await File(d.path).readAsBytes();
      if (d.mime.startsWith('image/')) {
        return AttachmentSeed.image(name: d.name, bytes: bytes);
      } else {
        return AttachmentSeed.file(name: d.name, bytes: bytes);
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSingleInChat(_DocItem d) async {
    final seed = await _buildSeed(d);
    if (seed == null) {
      _snack('Could not read file');
      return;
    }
    final store = SqlChatStore();
    final chatId = await store.createChat(
      name: 'Doc: ${d.name}',
      preset: {'kind': 'tool', 'id': 'travel_docs'},
    );
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatPage(
        userId: widget.userId,
        chatId: chatId,
        chatName: 'Doc: ${d.name}',
        initialAttachments: [seed],
        autoSendInitialAttachments: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _docs
        : _docs.where((d) => d.name.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Docs'),
        actions: [
          IconButton(
            tooltip: 'Send to Chat',
            onPressed: filtered.isEmpty
                ? null
                : () async {
                    final picked = _selected.isEmpty ? filtered : filtered.where((d) => _selected.contains(d.path)).toList();
                    if (picked.isEmpty) {
                      _snack('Select documents first');
                      return;
                    }
                    final store = SqlChatStore();
                    final chatId = await store.createChat(
                      name: 'Docs',
                      preset: {'kind': 'tool', 'id': 'travel_docs'},
                    );
                    final seeds = <AttachmentSeed>[];
                    for (final d in picked) {
                      final seed = await _buildSeed(d);
                      if (seed != null) seeds.add(seed);
                    }
                    if (!mounted) return;
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatPage(
                        userId: widget.userId,
                        chatId: chatId,
                        chatName: 'Docs',
                        initialAttachments: seeds,
                        autoSendInitialAttachments: true,
                      ),
                    ));
                  },
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          _Card(
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Search (e.g. passport, visa, photo)…',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconBtn(icon: Icons.photo_camera_rounded, onTap: _addFromCamera, tooltip: 'Camera'),
                  const SizedBox(width: 6),
                  _IconBtn(icon: Icons.upload_file_rounded, onTap: _addFromFiles, tooltip: 'Upload'),
                ]),
                const SizedBox(height: 10),
                _DropZone(onTap: _addFromFiles),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Center(child: Text('No documents yet. Add some!')),
          if (filtered.isNotEmpty)
            _Card(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: filtered.map((d) {
                  final selected = _selected.contains(d.path);
                  return _DocBubble(
                    item: d,
                    selected: selected,
                    onToggle: () async {
                      if (_selected.isEmpty) {
                        await _openSingleInChat(d); // open chat & auto-send this file
                      } else {
                        setState(() {
                          if (selected) {
                            _selected.remove(d.path);
                          } else {
                            _selected.add(d.path);
                          }
                        });
                      }
                    },
                    onDelete: () async {
                      setState(() {
                        _docs.removeWhere((x) => x.path == d.path);
                        _selected.remove(d.path);
                      });
                      await _persist();
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/* ───────────────────────── SMART TOOL PAGE (asks user first) ───────────────────────── */

class _SmartToolPage extends StatefulWidget {
  final String toolId;
  final String title;
  final String destHint;
  final String brief;
  final _Trip? trip;

  const _SmartToolPage({
    required this.toolId,
    required this.title,
    required this.destHint,
    required this.brief,
    required this.trip,
  });

  @override
  State<_SmartToolPage> createState() => _SmartToolPageState();
}

class _SmartToolPageState extends State<_SmartToolPage> {
  final _ts = _TripStore();
  bool _busy = false;
  String _out = '';

  // Query form controllers
  final _loc = TextEditingController();
  DateTimeRange? _dates;
  final _extra = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loc.text = widget.destHint;
    _restore();
  }

  Future<void> _restore() async {
    final k = 'tool_${widget.toolId}_last';
    _out = (await _ts.loadValue(widget.trip?.id, k)) ?? '';
    if (mounted) setState(() {});
  }

  String _buildAsk() {
    final place = _loc.text.trim().isEmpty ? 'the destination' : _loc.text.trim();
    final when = _dates == null ? 'any time' : '${_d(_dates!.start)} to ${_d(_dates!.end)}';
    final extra = _extra.text.trim();

    String suffix = '\n${extra.isEmpty ? '' : 'Notes: $extra\n'}Answer in **English only**.';

    switch (widget.toolId) {
      case 'safety':
        return '''
List **safety tips & common scams** in $place for $when:
- 6–10 bullet points, practical and specific (areas, taxi/menus/bar/ATM scams)
- Emergency numbers and 3–5 helpful local phrases.
$suffix
''';
      case 'budget':
        return '''
Estimate a **budget breakdown (INR)** for a trip to $place during $when.
Show per-person daily range and total trip range.
Split: Flights (approx from India), Stay, Food, Transport, Activities, Misc.
${extra.isEmpty ? '' : 'Constraints: $extra'}
Answer in **English only**.
''';
      case 'besttime':
        return '''
Explain the **best time to visit $place**:
- Weather by month (temp/rain) ranges
- High/shoulder/low seasons and crowd
- Festivals/events worth timing
- What to pack for $when
Crisp bullets only.
$suffix
''';
      case 'transport':
        return '''
How to **get around $place** for $when:
- Airport to city options (cost INR + time)
- Local transport (metro/passes, bus cards, ride-hail)
- Typical fares (INR)
- When to walk; areas to avoid late-night
Short bullets.
$suffix
''';
      case 'sim':
        return '''
Give **SIM / eSIM** guidance for $place for $when:
- Top providers, best tourist packs (data, validity, approx INR)
- Where to buy/activate; ID needed?
- Roaming vs local eSIM pros/cons
$suffix
''';
      case 'food':
        return '''
List **must-try foods** in $place and 6–8 places/streets/areas to try them,
1-line why each. If you know great value/local spots, include them.
$suffix
''';
      case 'spots':
        return '''
Suggest **photography spots** in/around $place for $when:
- Sunrise / Golden hour / Night city views
- Iconic landmarks vantage points
- Hidden gems
Add quick access/fee notes if any.
$suffix
''';
      case 'daytrips':
        return '''
Recommend **day trips** near $place (3–6) for $when:
- Distance and travel time
- What to see/do
- Quick budget note (INR)
$suffix
''';
      default:
        return 'Travel help. Answer in English only.';
    }
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final r = await GPMaiBrain.send(_buildAsk());
      setState(() => _out = _stripMood(r).trim());
      await _ts.saveValue(widget.trip?.id, 'tool_${widget.toolId}_last', _out);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_rounded, color: _electricBlue),
            onPressed: _out.isEmpty ? null : () async {
              await _ts.saveValue(widget.trip?.id, 'tool_${widget.toolId}_last', _out);
              _snack('Saved');
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              setState(() => _out = '');
              await _ts.saveValue(widget.trip?.id, 'tool_${widget.toolId}_last', '');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          // Query form first
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Labeled('Location', child: TextField(
                  controller: _loc,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Singapore, Bali, Paris…',
                    border: OutlineInputBorder(),
                  ),
                )),
                const SizedBox(height: 8),
                _Labeled('Date range (optional)', child: _DateInline(
                  label: _dates == null ? 'Pick dates' : '${_d(_dates!.start)} → ${_d(_dates!.end)}',
                  onPick: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: now,
                      lastDate: DateTime(now.year + 2),
                    );
                    if (!mounted) return;
                    setState(() => _dates = picked);
                  },
                )),
                const SizedBox(height: 8),
                _Labeled('Extra preferences (optional)', child: TextField(
                  controller: _extra,
                  decoration: const InputDecoration(
                    hintText: 'Diet, kid-friendly, budget notes, areas to focus/avoid…',
                    border: OutlineInputBorder(),
                  ),
                )),
                const SizedBox(height: 10),
                _PrimaryButton(
                  label: _busy ? 'Working…' : 'Generate',
                  icon: Icons.flash_on_rounded,
                  onTap: _busy ? null : _generate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_out.isNotEmpty)
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarkdownBubble(
                    text: _out,
                    textColor: isLight ? Colors.black87 : Colors.white,
                    linkColor: _electricBlue,
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _PillButton(
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      onTap: () async {
                        final edited = await _editText(context, _out, title: 'Edit "${widget.title}"');
                        if (edited == null) return;
                        setState(() => _out = edited);
                        await _ts.saveValue(widget.trip?.id, 'tool_${widget.toolId}_last', _out);
                      },
                    ),
                    _PillButton(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: _out));
                        _snack('Copied');
                      },
                    ),
                    _PillButton(
                      icon: Icons.save_rounded,
                      label: 'Save',
                      onTap: () async {
                        await _ts.saveValue(widget.trip?.id, 'tool_${widget.toolId}_last', _out);
                        _snack('Saved');
                      },
                    ),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  static String _stripMood(String s) =>
      s.replaceAll(RegExp(r'\\[mood:[^\\]]*\\]', caseSensitive: false), '');
}

/* ───────────────────────── TRIPS (FOLDERS) MANAGER ───────────────────────── */

class _TripDraft {
  final String dest;
  final DateTimeRange? range;
  const _TripDraft({required this.dest, required this.range});
}

enum _TripActionKind { select, created, deleted }

class _TripAction {
  final _TripActionKind kind;
  final _Trip? trip;
  const _TripAction(this.kind, this.trip);
}

class _TripsManagerPage extends StatefulWidget {
  final _TripDraft currentDraft;
  const _TripsManagerPage({required this.currentDraft});

  @override
  State<_TripsManagerPage> createState() => _TripsManagerPageState();
}

class _TripsManagerPageState extends State<_TripsManagerPage> {
  final _ts = _TripStore();
  List<_Trip> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _items = await _ts.list();
    if (mounted) setState(() {});
  }

  Future<void> _createFromDraft() async {
    final t = _Trip(
      id: 'trip_${DateTime.now().microsecondsSinceEpoch}',
      title: widget.currentDraft.dest.isEmpty ? 'New Trip' : widget.currentDraft.dest,
      start: widget.currentDraft.range?.start,
      end: widget.currentDraft.range?.end,
    );
    await _ts.upsert(t);
    if (!mounted) return;
    Navigator.pop(context, _TripAction(_TripActionKind.created, t));
  }

  Future<void> _rename(_Trip t) async {
    final c = TextEditingController(text: t.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename trip'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Trip name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    t.title = newName;
    await _ts.upsert(t);
    await _load();
  }

  Future<void> _delete(_Trip t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text('This removes the trip from your folders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _ts.delete(t.id);
    if (!mounted) return;
    Navigator.pop(context, _TripAction(_TripActionKind.deleted, t));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          TextButton.icon(
            onPressed: _createFromDraft,
            icon: const Icon(Icons.create_new_folder_rounded, color: Colors.white),
            label: const Text('New from current', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No trips yet. Use “New from current”.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final t = _items[i];
                final subtitle = (t.start == null || t.end == null)
                    ? 'Dates: flexible'
                    : 'Dates: ${_d(t.start!)} → ${_d(t.end!)}';
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: cs.onSurface.withOpacity(.18)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isLight ? Colors.black.withOpacity(.06) : cs.surfaceVariant.withOpacity(.3),
                      child: const Icon(Icons.folder_rounded, color: _electricBlue),
                    ),
                    title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(subtitle),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') _rename(t);
                        if (v == 'delete') _delete(t);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => Navigator.pop(context, _TripAction(_TripActionKind.select, t)),
                  ),
                );
              },
            ),
    );
  }
}

/* ───────────────────────── DATA LAYERS ───────────────────────── */

class _Trip {
  final String id;
  String title;
  final DateTime? start;
  final DateTime? end;

  _Trip({required this.id, required this.title, this.start, this.end});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start?.millisecondsSinceEpoch,
        'end': end?.millisecondsSinceEpoch,
      };

  static _Trip fromJson(Map<String, dynamic> j) => _Trip(
        id: j['id'] as String,
        title: j['title'] as String,
        start: j['start'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['start'] as int),
        end: j['end'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['end'] as int),
      );
}

class _TripStore {
  // Backed by _LocalStore on a dedicated name.
  final _LocalStore _kv = _LocalStore('__TRAVEL_TRIPS__');

  Future<List<_Trip>> list() async {
    final s = await _kv.load('trips_index');
    if (s == null || s.isEmpty) return [];
    try {
      final arr = (jsonDecode(s) as List).cast<Map>();
      return arr.map((m) => _Trip.fromJson(Map<String, dynamic>.from(m))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<_Trip?> getById(String id) async {
    final all = await list();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(_Trip t) async {
    final all = await list();
    final i = all.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      all[i] = t;
    } else {
      all.add(t);
    }
    await _kv.save('trips_index', jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> delete(String id) async {
    final all = await list();
    all.removeWhere((e) => e.id == id);
    await _kv.save('trips_index', jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> saveValue(String? tripId, String key, String value) async {
    if (tripId == null || tripId.isEmpty) {
      await _kv.save('global_$key', value);
      return;
    }
    await _kv.save('trip_${tripId}_$key', value);
  }

  Future<String?> loadValue(String? tripId, String key) async {
    if (tripId == null || tripId.isEmpty) {
      return _kv.load('global_$key');
    }
    return _kv.load('trip_${tripId}_$key');
  }
}

// Simple KV store using SqlChatStore (messages).
class _LocalStore {
  final String chatName;
  final SqlChatStore _sql = SqlChatStore();
  String? _chatId;
  _LocalStore(this.chatName);

  Future<String> _ensure() async {
    if (_chatId != null) return _chatId!;
    final all = await _sql.watchChats(starredOnly: false).first;
    for (final c in all) {
      if (c.name == chatName) {
        _chatId = c.id;
        return _chatId!;
      }
    }
    _chatId = await _sql.createChat(name: chatName);
    return _chatId!;
  }

  Future<void> save(String key, String value) async {
    final id = await _ensure();
    await _sql.addMessage(chatId: id, role: 'system', text: '[KV:$key]\\n$value');
  }

  Future<String?> load(String key) async {
    final id = await _ensure();
    final msgs = await _sql.watchMessages(id).first;
    for (final m in msgs.reversed) {
      final t = m.text;
      final p = '[KV:$key]\\n';
      if (t.startsWith(p)) return t.substring(p.length);
    }
    return null;
  }
}

/* ───────────────────────── Small UI bits ───────────────────────── */

class _Tabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(.18)),
      ),
      child: const TabBar(
        labelPadding: EdgeInsets.symmetric(vertical: 10),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _electricBlue,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(text: 'Plan'),
          Tab(text: 'Tools'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isLight ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.onSurface.withOpacity(.18), width: 1.2),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 46,
        decoration: BoxDecoration(
          color: _electricBlue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: cs.surfaceVariant.withOpacity(.16),
          border: Border.all(color: cs.onSurface.withOpacity(.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  const _RoundIcon({required this.onTap, required this.icon});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceVariant.withOpacity(.18),
          border: Border.all(color: cs.onSurface.withOpacity(.18)),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _InterestChips extends StatelessWidget {
  final Set<String> values;
  final ValueChanged<String> onToggle;
  const _InterestChips({required this.values, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const all = [
      'Food','Nature','Beaches','History','Nightlife',
      'Shopping','Adventure','Museums','Road Trip','Mountains'
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: all.map((t) {
        final sel = values.contains(t);
        return InkWell(
          onTap: () => onToggle(t),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: sel ? _electricBlue : cs.surfaceVariant.withOpacity(.14),
              border: Border.all(color: cs.onSurface.withOpacity(.18)),
            ),
            child: Text(t, style: TextStyle(color: sel ? Colors.black : cs.onSurface)),
          ),
        );
      }).toList(),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateRow({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withOpacity(.18)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0x2A00B8FF),
              child: Icon(Icons.date_range_rounded, color: _electricBlue, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labeled(this.label, {required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      child,
    ]);
  }
}

class _DateInline extends StatelessWidget {
  final String label;
  final VoidCallback onPick;
  const _DateInline({required this.label, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.onSurface.withOpacity(.18)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Icon(Icons.date_range_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ]),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  const _NotesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      decoration: const InputDecoration(
        labelText: 'Notes / Preferences (optional)',
        hintText: 'e.g. prefer near metro, vegetarian food, avoid long hikes…',
        border: OutlineInputBorder(),
      ),
      textInputAction: TextInputAction.newline,
    );
  }
}

class _Tool {
  final String id;
  final String title;
  final IconData icon;
  const _Tool(this.id, this.title, this.icon);
}

class _ToolTile extends StatelessWidget {
  final _Tool tool;
  final VoidCallback onTap;
  const _ToolTile({required this.tool, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              cs.surface.withOpacity(.12),
              cs.surfaceVariant.withOpacity(.16),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: cs.onSurface.withOpacity(.18)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surface.withOpacity(.06),
              border: Border.all(color: cs.onSurface.withOpacity(.18)),
            ),
            child: Icon(tool.icon, color: cs.primary),
          ),
          const SizedBox(height: 8),
          Text(
            tool.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cs.onSurface),
          ),
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn({required this.icon, required this.onTap, required this.tooltip});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: cs.surfaceVariant.withOpacity(.12),
            border: Border.all(color: cs.onSurface.withOpacity(.18)),
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _DocItem {
  final String name;
  final String path;
  final String mime;
  final int ts;
  _DocItem({required this.name, required this.path, required this.mime, required this.ts});

  Map<String, dynamic> toJson() => {'name': name, 'path': path, 'mime': mime, 'ts': ts};
  static _DocItem fromJson(Map<String, dynamic> j) =>
      _DocItem(name: j['name'] as String, path: j['path'] as String, mime: j['mime'] as String, ts: j['ts'] as int);
}

class _DocBubble extends StatelessWidget {
  final _DocItem item;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _DocBubble({required this.item, required this.selected, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ring = cs.onSurface.withOpacity(.18);

    IconData _iconForMime(String mime) {
      if (mime.contains('pdf')) return Icons.picture_as_pdf_rounded;
      if (mime.contains('image/')) return Icons.image_rounded;
      return Icons.insert_drive_file_rounded;
    }

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? _electricBlue : cs.surfaceVariant.withOpacity(.14),
          border: Border.all(color: selected ? _electricBlue : ring),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_iconForMime(item.mime), color: selected ? Colors.black : cs.primary, size: 18),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              item.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: selected ? Colors.black : cs.onSurface),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 16, color: selected ? Colors.black : cs.onSurface),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final VoidCallback onTap;
  const _DropZone({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cs.surfaceVariant.withOpacity(.12),
          border: Border.all(color: cs.onSurface.withOpacity(.18)),
        ),
        child: const Text('Tap to add files (photos, PDFs, etc.)'),
      ),
    );
  }
}

/* ───────────────────────── Customize Plan Page ───────────────────────── */

class _CustomizePlanPage extends StatefulWidget {
  final String original;
  final String current;
  final Future<String> Function(String selection, String instructions) onRegenerate;
  const _CustomizePlanPage({
    required this.original,
    required this.current,
    required this.onRegenerate,
  });

  @override
  State<_CustomizePlanPage> createState() => _CustomizePlanPageState();
}

class _CustomizePlanPageState extends State<_CustomizePlanPage> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.current);
  final TextEditingController _instr = TextEditingController(text: 'Tighten timings and add short commute hints.');
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _instr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Plan'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _ctrl.text = widget.original),
            child: const Text('Reset to AI'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: const Text('Apply'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _instr,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Instructions for selected text (optional)…',
                    border: OutlineInputBorder(),
                    labelText: 'Regenerate selection with…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : () async {
                  final sel = _ctrl.selection;
                  if (!sel.isValid || sel.isCollapsed) {
                    _snack('Select some text first');
                    return;
                  }
                  final pick = _ctrl.text.substring(sel.start, sel.end);
                  setState(() => _busy = true);
                  final rep = await widget.onRegenerate(pick, _instr.text.trim().isEmpty ? 'Improve clarity' : _instr.text.trim());
                  final newText = _ctrl.text.replaceRange(sel.start, sel.end, rep);
                  setState(() {
                    _ctrl.text = newText;
                    _ctrl.selection = TextSelection.collapsed(offset: sel.start + rep.length);
                    _busy = false;
                  });
                },
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text(_busy ? 'Working…' : 'Regenerate selection'),
                style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.black),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: TextField(
                controller: _ctrl,
                expands: true,
                maxLines: null,
                minLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Edit your plan directly. Select text to regenerate just that part.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

/* ───────────────────────── helpers ───────────────────────── */

String _d(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _two(int n) => n < 10 ? '0$n' : '$n';
String _stripMood(String s) =>
    s.replaceAll(RegExp(r'\\[mood:[^\\]]*\\]', caseSensitive: false), '');

// Edit helper dialog
Future<String?> _editText(BuildContext context, String original, {required String title}) async {
  final c = TextEditingController(text: original);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 600,
        child: TextField(
          controller: c,
          minLines: 10,
          maxLines: 18,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
      ],
    ),
  );
}