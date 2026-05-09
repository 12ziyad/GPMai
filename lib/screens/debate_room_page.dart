import 'dart:async';

import 'package:flutter/material.dart';

import '../services/curated_models.dart';
import '../services/debate_room_engine.dart';
import '../services/debate_room_store.dart';
import '../services/provider_branding.dart';
import '../services/research_canvas_store.dart';
import '../widgets/save_to_canvas_sheet.dart';
import '../widgets/markdown_bubble.dart';
import '../widgets/citation_builder_panel.dart';
import '../widgets/auto_prompt_chips.dart';

class DebateRoomPage extends StatefulWidget {
  final String userId;

  const DebateRoomPage({super.key, required this.userId});

  @override
  State<DebateRoomPage> createState() => _DebateRoomPageState();
}

class _DebateRoomPageState extends State<DebateRoomPage> {
  final DebateRoomStore _store = DebateRoomStore();
  bool _loading = true;
  List<DebateRoomSession> _sessions = const <DebateRoomSession>[];
  final Set<String> _selected = <String>{};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _startNew() async {
    final created = await Navigator.of(context).push<DebateRoomSession>(
      MaterialPageRoute(builder: (_) => const _DebateRoomSetupPage()),
    );
    if (created == null || !mounted) return;
    await _store.upsert(created);
    await _openSession(created.id, runIfNeeded: true);
    await _load();
  }

  Future<void> _openSession(String id, {bool runIfNeeded = false}) async {
    final session = await _store.getById(id);
    if (session == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _DebateRoomSessionPage(
              initialSession: session,
              runIfNeeded: runIfNeeded,
            ),
      ),
    );
    await _load();
  }

  Future<void> _renameSession(DebateRoomSession session) async {
    final ctrl = TextEditingController(text: session.title);
    final next = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Rename Debate Room session'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Debate title'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );
    if (next == null || next.trim().isEmpty) return;
    await _store.rename(session.id, next.trim());
    await _load();
  }

  Future<void> _deleteSessions(List<DebateRoomSession> sessions) async {
    if (sessions.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete sessions?'),
            content: Text('Delete ${sessions.length} Debate Room session(s)?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    for (final item in sessions) {
      await _store.delete(item.id);
    }
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
    await _load();
  }

  void _toggleSelection(String id) {
    setState(() {
      _selectionMode = true;
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  AppBar _appBar() {
    if (!_selectionMode) {
      return AppBar(
        title: const Text('Debate Room'),
        actions: [
          IconButton(
            onPressed: _startNew,
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Start debate',
          ),
        ],
      );
    }

    return AppBar(
      leading: IconButton(
        onPressed:
            () => setState(() {
              _selectionMode = false;
              _selected.clear();
            }),
        icon: const Icon(Icons.close_rounded),
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          onPressed:
              () => setState(() {
                final visible = _sessions.map((e) => e.id).toSet();
                if (_selected.length == visible.length) {
                  _selected.clear();
                  _selectionMode = false;
                } else {
                  _selected
                    ..clear()
                    ..addAll(visible);
                }
              }),
          icon: const Icon(Icons.select_all_rounded),
          tooltip: 'Select all',
        ),
        IconButton(
          onPressed: () async {
            final selected = _sessions
                .where((e) => _selected.contains(e.id))
                .toList(growable: false);
            if (selected.length == 1) {
              await _store.togglePinned(selected.first.id);
              await _load();
            }
          },
          icon: const Icon(Icons.push_pin_outlined),
          tooltip: 'Pin',
        ),
        IconButton(
          onPressed:
              () => _deleteSessions(
                _sessions
                    .where((e) => _selected.contains(e.id))
                    .toList(growable: false),
              ),
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'Delete selected',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyCard =
        Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF0F131A);
    final border =
        Theme.of(context).brightness == Brightness.light
            ? Colors.black12
            : Colors.white12;

    return Scaffold(
      backgroundColor: const Color(0xFF090B11),
      appBar: _appBar(),
      floatingActionButton:
          _selectionMode
              ? null
              : FloatingActionButton.extended(
                onPressed: _startNew,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start Debate'),
              ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                    children: [
                      _HistoryHeroCard(onStart: _startNew),
                      const SizedBox(height: 18),
                      Text(
                        'Recent sessions',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_sessions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: bodyCard,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: border),
                          ),
                          child: const Text(
                            'No saved debates yet. Choose three models and watch the room build one answer together.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        )
                      else
                        ..._sessions.map((session) {
                          final selected = _selected.contains(session.id);
                          final accent =
                              session.participants.isEmpty
                                  ? const Color(0xFF00B8FF)
                                  : ProviderBranding.resolve(
                                    provider:
                                        session.participants.first.provider,
                                    modelId: session.participants.first.modelId,
                                    displayName:
                                        session.participants.first.displayName,
                                  ).accent;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onLongPress: () => _toggleSelection(session.id),
                              onTap: () {
                                if (_selectionMode) {
                                  _toggleSelection(session.id);
                                  return;
                                }
                                _openSession(session.id);
                              },
                              child: Ink(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: bodyCard,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? accent.withOpacity(.7)
                                            : border,
                                    width: selected ? 1.4 : 1,
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      accent.withOpacity(.14),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_selectionMode)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                          top: 2,
                                        ),
                                        child: Checkbox(
                                          value: selected,
                                          onChanged:
                                              (_) =>
                                                  _toggleSelection(session.id),
                                        ),
                                      ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  session.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 17,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              if (session.pinned)
                                                Icon(
                                                  Icons.push_pin_rounded,
                                                  size: 18,
                                                  color: accent,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            session.question,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _TinyPill(label: session.goal),
                                              _TinyPill(label: session.depth),
                                              _TinyPill(label: session.status),
                                              ...session.participants
                                                  .take(3)
                                                  .map(
                                                    (p) => _TinyPill(
                                                      label: p.displayName,
                                                    ),
                                                  ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!_selectionMode)
                                      PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'rename') {
                                            await _renameSession(session);
                                          } else if (value == 'pin') {
                                            await _store.togglePinned(
                                              session.id,
                                            );
                                            await _load();
                                          } else if (value == 'delete') {
                                            await _deleteSessions([session]);
                                          }
                                        },
                                        itemBuilder:
                                            (_) => [
                                              const PopupMenuItem(
                                                value: 'rename',
                                                child: Text('Rename'),
                                              ),
                                              PopupMenuItem(
                                                value: 'pin',
                                                child: Text(
                                                  session.pinned
                                                      ? 'Unpin'
                                                      : 'Pin',
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
      ),
    );
  }
}

class _HistoryHeroCard extends StatelessWidget {
  final VoidCallback onStart;

  const _HistoryHeroCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF132132), Color(0xFF1D1630), Color(0xFF090B11)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF00B8FF).withOpacity(.14),
                  border: Border.all(
                    color: const Color(0xFF00B8FF).withOpacity(.42),
                  ),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Color(0xFF00B8FF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debate Room',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Three selected models. Live panel discussion. Moderator-guided convergence. One final approved answer.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _TinyPill(label: '3 selected models'),
              _TinyPill(label: 'LIVE room'),
              _TinyPill(label: 'Moderator summaries'),
              _TinyPill(label: 'Final approval loop'),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start New Debate'),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String label;
  const _TinyPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DebateRoomSetupPage extends StatefulWidget {
  const _DebateRoomSetupPage();

  @override
  State<_DebateRoomSetupPage> createState() => _DebateRoomSetupPageState();
}

class _DebateRoomSetupPageState extends State<_DebateRoomSetupPage> {
  final TextEditingController _questionCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _goal = 'Best answer';
  String _outputStyle = 'Action plan';
  String _depth = 'Balanced';
  final List<CuratedModel> _selected = <CuratedModel>[];

  List<CuratedModel> get _supportedModels {
    final models = mixedOfficialModels.where((m) => m.official);
    return models.take(36).toList(growable: false);
  }

  List<CuratedModel> get _filteredModels {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _supportedModels;
    return _supportedModels
        .where((m) {
          final hay =
              '${m.displayName} ${m.provider} ${m.description} ${m.id}'
                  .toLowerCase();
          return hay.contains(q);
        })
        .toList(growable: false);
  }

  bool get _ready =>
      _selected.length == 3 && _questionCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_refresh);
    _questionCtrl.addListener(_refresh);
    _selected.addAll(_supportedModels.take(3));
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _toggleModel(CuratedModel model) {
    setState(() {
      final exists = _selected.any((e) => e.id == model.id);
      if (exists) {
        _selected.removeWhere((e) => e.id == model.id);
      } else if (_selected.length < 3) {
        _selected.add(model);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose exactly 3 models for this room.'),
          ),
        );
      }
    });
  }

  void _submit({String? promptChipLabel}) {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty || _selected.length != 3) return;
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final session = DebateRoomSession(
      id: id,
      title: DebateRoomEngine.makeTitle(question),
      question: question,
      goal: _goal,
      outputStyle: _outputStyle,
      depth: _depth,
      participants: _selected
          .map(
            (m) => DebateRoomParticipant(
              modelId: m.id,
              displayName: m.displayName,
              provider: m.provider,
            ),
          )
          .toList(growable: false),
      events: const <DebateRoomEvent>[],
      status: 'queued',
      createdAt: now,
      updatedAt: now,
    );
    Navigator.of(context).pop(session);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B11),
      appBar: AppBar(
        title: const Text('Start Debate'),
        backgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF090B11).withOpacity(.96),
          border: const Border(top: BorderSide(color: Colors.white12)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _selected.length == 3 ? 1 : .72,
            child: SizedBox(
              height: 58,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00B8FF),
                      Color(0xFF8D63FF),
                      Color(0xFF3B7DFF),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300B8FF),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _ready ? _submit : null,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    _ready
                        ? 'Start Debate Room'
                        : 'Choose 3 models and add the question',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _SetupHeroCard(),
            const SizedBox(height: 16),
            _QuestionSection(
              controller: _questionCtrl,
              onSubmitWithChip: (transformedText, chipType, chipLabel) async {
                _questionCtrl.text = transformedText;
                _questionCtrl.selection = TextSelection.collapsed(
                  offset: _questionCtrl.text.length,
                );
                if (_selected.length == 3 &&
                    transformedText.trim().isNotEmpty) {
                  _submit(promptChipLabel: chipLabel);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Prompt applied. Choose 3 models to start the room.',
                      ),
                    ),
                  );
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 16),
            _DarkSection(
              title: 'Debate goal',
              subtitle:
                  'Control how the panel behaves and what it should optimize for.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                              'Best answer',
                              'Compare options',
                              'Find risks',
                              'Challenge my thinking',
                            ]
                            .map(
                              (e) => _DarkChoiceChip(
                                label: e,
                                selected: _goal == e,
                                onTap: () => setState(() => _goal = e),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                              'Action plan',
                              'Decision verdict',
                              'Teacher summary',
                              'Pros vs cons',
                            ]
                            .map(
                              (e) => _DarkChoiceChip(
                                label: e,
                                selected: _outputStyle == e,
                                onTap: () => setState(() => _outputStyle = e),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        ['Fast', 'Balanced', 'Deep']
                            .map(
                              (e) => _DarkChoiceChip(
                                label: e,
                                selected: _depth == e,
                                onTap: () => setState(() => _depth = e),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DarkSection(
              title: 'Choose 3 models',
              subtitle:
                  'The selected trio appears above and powers the whole live room.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selected.isNotEmpty) ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          _selected
                              .map(
                                (m) => _SelectedModelChip(
                                  model: m,
                                  onRemove: () => _toggleModel(m),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search models',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color(0xFF00B8FF),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._filteredModels.map((model) {
                    final selected = _selected.any((e) => e.id == model.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ModelPickTile(
                        model: model,
                        selected: selected,
                        onTap: () => _toggleModel(model),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupHeroCard extends StatelessWidget {
  const _SetupHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF142031), Color(0xFF1B1429), Color(0xFF090B11)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build the room carefully',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Pick exactly three models, frame the question clearly, and let the room negotiate toward one final answer.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _QuestionSection extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function(
    String transformedText,
    String chipType,
    String chipLabel,
  )?
  onSubmitWithChip;
  const _QuestionSection({required this.controller, this.onSubmitWithChip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171F33), Color(0xFF151225), Color(0xFF0B0E15)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Main question',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Frame it like something that matters. The room works best when the question is real, focused, and difficult enough to benefit from negotiation.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x2812C6FF),
                  Color(0x228D63FF),
                  Color(0x16090B11),
                ],
              ),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: controller,
              minLines: 4,
              maxLines: 7,
              style: const TextStyle(color: Colors.white, height: 1.4),
              decoration: InputDecoration(
                hintText:
                    'Should I ship my AI app smaller first, or go broader and accept more backend complexity now?',
                hintStyle: const TextStyle(color: Colors.white38, height: 1.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AutoPromptChips(
            controller: controller,
            screenContext: 'debate',
            onSend: (transformedText, chipType, chipLabel) async {
              controller.text = transformedText;
              controller.selection = TextSelection.collapsed(
                offset: controller.text.length,
              );
              await onSubmitWithChip?.call(
                transformedText,
                chipType,
                chipLabel,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DarkSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DarkSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F131A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DarkChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DarkChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient:
              selected
                  ? const LinearGradient(
                    colors: [Color(0xFF12C6FF), Color(0xFF8D63FF)],
                  )
                  : null,
          color: selected ? null : Colors.white.withOpacity(.05),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _SelectedModelChip extends StatelessWidget {
  final CuratedModel model;
  final VoidCallback onRemove;

  const _SelectedModelChip({required this.model, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final brand = ProviderBranding.resolve(
      provider: model.provider,
      modelId: model.id,
      displayName: model.displayName,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: brand.vividGradient(Brightness.dark)),
        border: Border.all(color: brand.border(Brightness.dark), width: 1.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: brand.iconFill(Brightness.dark),
            ),
            child: Center(
              child: Text(
                brand.initials(model.provider),
                style: TextStyle(
                  color: brand.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            model.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 18, color: brand.accent),
          ),
        ],
      ),
    );
  }
}

class _ModelPickTile extends StatelessWidget {
  final CuratedModel model;
  final bool selected;
  final VoidCallback onTap;

  const _ModelPickTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = ProviderBranding.resolve(
      provider: model.provider,
      modelId: model.id,
      displayName: model.displayName,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: brand.cardGradient(Brightness.dark)),
          border: Border.all(
            color: selected ? brand.border(Brightness.dark) : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: brand.iconFill(Brightness.dark),
                border: Border.all(color: brand.border(Brightness.dark)),
              ),
              child: Center(
                child: Text(
                  brand.initials(model.provider),
                  style: TextStyle(
                    color: brand.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.provider,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: selected ? brand.accent : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

class _DebateRoomSessionPage extends StatefulWidget {
  final DebateRoomSession initialSession;
  final bool runIfNeeded;

  const _DebateRoomSessionPage({
    required this.initialSession,
    required this.runIfNeeded,
  });

  @override
  State<_DebateRoomSessionPage> createState() => _DebateRoomSessionPageState();
}

class _DebateRoomSessionPageState extends State<_DebateRoomSessionPage> {
  final DebateRoomStore _store = DebateRoomStore();
  final TextEditingController _interventionCtrl = TextEditingController();
  late DebateRoomSession _session;
  bool _running = false;
  Timer? _ticker;

  int get _interventionsUsed =>
      _session.events.where((e) => e.type == 'user_intervention').length;
  bool get _canIntervene => _session.liveWindowOpen && _interventionsUsed < 2;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _restartTicker();
    if (widget.runIfNeeded && _session.status != 'completed') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _interventionCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveToCanvas() async {
    if ((_session.finalSummary ?? '').trim().isEmpty) return;
    final transcript = _session.events
        .where((e) => e.type != 'system' && e.content.trim().isNotEmpty)
        .map(
          (e) => <String, dynamic>{
            'speaker':
                e.type == 'moderator'
                    ? 'Moderator'
                    : (e.modelName ?? e.provider ?? 'Panelist'),
            'stage': e.stage,
            'content': e.content,
          },
        )
        .toList(growable: false);
    await SaveToCanvasSheet.open(
      context,
      draft: ResearchCanvasBlockDraft(
        type: 'debate',
        title: _session.title,
        question: _session.question,
        content: _session.finalSummary ?? '',
        sourceLabel: 'Debate Room',
        modelLabel: 'Moderator-approved panel',
        tags: const <String>[],
        extra: <String, dynamic>{'transcript': transcript},
      ),
    );
  }

  void _restartTicker() {
    _ticker?.cancel();
    if (_session.liveWindowOpen && _session.liveEndsAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!_session.liveWindowOpen || _session.liveEndsAt == null) {
          _ticker?.cancel();
          return;
        }
        setState(() {});
      });
    }
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await DebateRoomEngine.runSession(
        initial: _session,
        loadLatestSession: () => _store.getById(_session.id),
        onUpdate: (update) async {
          _session = update.session;
          await _store.upsert(_session);
          if (mounted) {
            _restartTicker();
            setState(() {});
          }
        },
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _sendIntervention() async {
    final text = _interventionCtrl.text.trim();
    if (text.isEmpty || !_canIntervene) return;
    final next = _session.copyWith(
      events: <DebateRoomEvent>[
        ..._session.events,
        DebateRoomEvent(
          id: '${_session.id}_user_${DateTime.now().microsecondsSinceEpoch}',
          round: 2,
          stage: 'Live Panel Discussion',
          type: 'user_intervention',
          modelName: 'You',
          provider: 'User',
          content: text,
          createdAt: DateTime.now(),
        ),
      ],
      updatedAt: DateTime.now(),
    );
    _interventionCtrl.clear();
    _session = next;
    await _store.upsert(next);
    if (mounted) setState(() {});
  }

  String _liveCountdownText() {
    if (!_session.liveWindowOpen || _session.liveEndsAt == null) return '';
    final seconds = _session.liveEndsAt!.difference(DateTime.now()).inSeconds;
    if (seconds <= 0) return 'Closing…';
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B11),
      appBar: AppBar(
        title: Text(_session.title),
        actions: [
          if ((_session.finalSummary ?? '').trim().isNotEmpty)
            IconButton(
              onPressed: _saveToCanvas,
              icon: const Icon(Icons.auto_awesome_mosaic_rounded),
              tooltip: 'Save to Canvas',
            ),
          if (_session.status != 'completed')
            TextButton(
              onPressed: _running ? null : _run,
              child: Text(_running ? 'Running' : 'Resume'),
            ),
        ],
      ),
      bottomNavigationBar:
          _session.liveWindowOpen
              ? Container(
                padding: EdgeInsets.fromLTRB(
                  14,
                  10,
                  14,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF090B11).withOpacity(.97),
                  border: const Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _LiveChip(label: 'LIVE ${_liveCountdownText()}'),
                        const SizedBox(width: 10),
                        Text(
                          '${2 - _interventionsUsed} corrections left',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _interventionCtrl,
                            enabled: _canIntervene,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText:
                                  _canIntervene
                                      ? 'Focus the panel a little…'
                                      : 'No more corrections left',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withOpacity(.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Colors.white12,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Colors.white12,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xFF00B8FF),
                                  width: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _canIntervene ? _sendIntervention : null,
                            child: const Text('Send'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
              : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SessionHero(session: _session, liveLabel: _liveCountdownText()),
            const SizedBox(height: 14),
            ..._buildEventBlocks(),
            if (_session.status == 'completed' &&
                (_session.finalSummary ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _FinalSummaryCard(
                summary: _session.finalSummary!,
                responseId: 'debate_final_${_session.id}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEventBlocks() {
    final widgets = <Widget>[];
    String? lastStage;
    for (final event in _session.events) {
      if (event.type == 'system') {
        widgets.add(_StageBanner(title: event.stage, subtitle: event.content));
        widgets.add(const SizedBox(height: 10));
        lastStage = event.stage;
        continue;
      }
      if (event.type == 'summary') continue;
      if (event.stage != lastStage) {
        widgets.add(_StageHeader(label: event.stage));
        widgets.add(const SizedBox(height: 10));
        lastStage = event.stage;
      }
      if (event.type == 'moderator') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ModeratorEventCard(
              content: event.content,
              responseId: event.id,
            ),
          ),
        );
        continue;
      }
      if (event.type == 'user_intervention') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _UserInterventionCard(content: event.content),
          ),
        );
        continue;
      }
      final participant = _session.participants.firstWhere(
        (p) => p.modelId == event.modelId,
        orElse:
            () => DebateRoomParticipant(
              modelId: event.modelId ?? '',
              displayName: event.modelName ?? 'Panelist',
              provider: event.provider ?? '',
            ),
      );
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ParticipantEventCard(
            participant: participant,
            content: event.content,
            stage: event.stage,
            responseId: event.id,
          ),
        ),
      );
    }
    if (_running && _session.activeModelId != null) {
      final participant = _session.participants.firstWhere(
        (p) => p.modelId == _session.activeModelId,
        orElse: () => _session.participants.first,
      );
      widgets.add(
        _TypingParticipantCard(
          participant: participant,
          liveMode: _session.liveWindowOpen,
        ),
      );
    }
    return widgets;
  }
}

class _SessionHero extends StatelessWidget {
  final DebateRoomSession session;
  final String liveLabel;

  const _SessionHero({required this.session, required this.liveLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141B26), Color(0xFF19122B), Color(0xFF0A0D12)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.question,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.24,
                    color: Colors.white,
                  ),
                ),
              ),
              if (session.liveWindowOpen) _LiveChip(label: 'LIVE $liveLabel'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyPill(label: session.goal),
              _TinyPill(label: session.outputStyle),
              _TinyPill(label: session.depth),
              _TinyPill(label: session.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                session.participants.map((p) {
                  final brand = ProviderBranding.resolve(
                    provider: p.provider,
                    modelId: p.modelId,
                    displayName: p.displayName,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: brand.vividGradient(Brightness.dark),
                      ),
                      border: Border.all(color: brand.border(Brightness.dark)),
                    ),
                    child: Text(
                      p.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  final String label;
  const _LiveChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5B5B), Color(0xFF8D63FF)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  const _StageBanner({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF142031), Color(0xFF181128)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  final String label;
  const _StageHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white24)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white70,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white24)),
      ],
    );
  }
}

class _ParticipantEventCard extends StatelessWidget {
  final DebateRoomParticipant participant;
  final String content;
  final String stage;
  final String responseId;

  const _ParticipantEventCard({
    required this.participant,
    required this.content,
    required this.stage,
    required this.responseId,
  });

  @override
  Widget build(BuildContext context) {
    final brand = ProviderBranding.resolve(
      provider: participant.provider,
      modelId: participant.modelId,
      displayName: participant.displayName,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: brand.vividGradient(Brightness.dark),
        ),
        border: Border.all(color: brand.border(Brightness.dark), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: brand.accent.withOpacity(.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: brand.iconFill(Brightness.dark),
                  border: Border.all(color: brand.border(Brightness.dark)),
                ),
                child: Center(
                  child: Text(
                    brand.initials(participant.provider),
                    style: TextStyle(
                      color: brand.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      participant.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      participant.provider,
                      style: TextStyle(color: brand.mutedText(Brightness.dark)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: brand.accent.withOpacity(.18),
                ),
                child: Text(
                  stage,
                  style: TextStyle(
                    color: brand.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MarkdownBubble(
            text: content,
            textColor: Colors.white,
            linkColor: brand.accent,
          ),
          const SizedBox(height: 12),
          CitationBuilderPanel(
            responseText: content,
            responseId: responseId,
            accentColor: brand.accent,
          ),
        ],
      ),
    );
  }
}

class _ModeratorEventCard extends StatelessWidget {
  final String content;
  final String responseId;
  const _ModeratorEventCard({required this.content, required this.responseId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF162437), Color(0xFF151B2A), Color(0xFF0D1017)],
        ),
        border: Border.all(color: const Color(0xFF00B8FF).withOpacity(.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF00B8FF).withOpacity(.14),
                  border: Border.all(
                    color: const Color(0xFF00B8FF).withOpacity(.36),
                  ),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Color(0xFF00B8FF),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moderator',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Guiding the room, not debating',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF00B8FF).withOpacity(.12),
                ),
                child: const Text(
                  'Summary',
                  style: TextStyle(
                    color: Color(0xFF00B8FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'The moderator keeps the room aligned, explains what changed, and pushes the panel toward one shared answer.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 12),
          MarkdownBubble(
            text: content,
            textColor: Colors.white,
            linkColor: const Color(0xFF00B8FF),
          ),
          const SizedBox(height: 12),
          CitationBuilderPanel(
            responseText: content,
            responseId: responseId,
            accentColor: const Color(0xFF00B8FF),
          ),
        ],
      ),
    );
  }
}

class _UserInterventionCard extends StatelessWidget {
  final String content;
  const _UserInterventionCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(.07),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Your correction',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(color: Colors.white, height: 1.42),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingParticipantCard extends StatefulWidget {
  final DebateRoomParticipant participant;
  final bool liveMode;

  const _TypingParticipantCard({
    required this.participant,
    required this.liveMode,
  });

  @override
  State<_TypingParticipantCard> createState() => _TypingParticipantCardState();
}

class _TypingParticipantCardState extends State<_TypingParticipantCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = ProviderBranding.resolve(
      provider: widget.participant.provider,
      modelId: widget.participant.modelId,
      displayName: widget.participant.displayName,
    );
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(colors: brand.cardGradient(Brightness.dark)),
        border: Border.all(color: brand.border(Brightness.dark)),
      ),
      child: Row(
        children: [
          Text(
            widget.participant.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              final t = _controller.value;
              return Row(
                children: List.generate(3, (index) {
                  final scale = 0.75 + (((t + (index * .18)) % 1.0) * 0.4);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: brand.accent,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const Spacer(),
          Text(
            widget.liveMode ? 'Live reply' : 'Responding',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _FinalSummaryCard extends StatelessWidget {
  final String summary;
  final String responseId;
  const _FinalSummaryCard({required this.summary, required this.responseId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF161F2C), Color(0xFF1A1431), Color(0xFF0A0D12)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF00B8FF)),
              SizedBox(width: 10),
              Text(
                'Final Answer',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MarkdownBubble(
            text: summary,
            textColor: Colors.white,
            linkColor: const Color(0xFF00B8FF),
          ),
          const SizedBox(height: 12),
          CitationBuilderPanel(
            responseText: summary,
            responseId: responseId,
            accentColor: const Color(0xFF00B8FF),
          ),
        ],
      ),
    );
  }
}
