// lib/spaces/email_writer_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/gpmai_brain.dart';

class EmailWriterPage extends StatefulWidget {
  const EmailWriterPage({super.key});

  @override
  State<EmailWriterPage> createState() => _EmailWriterPageState();
}

enum ReplyState { none, interested, considering, notInterested, needMoreInfo, scheduleCall }

class _EmailWriterPageState extends State<EmailWriterPage>
    with SingleTickerProviderStateMixin {
  static const Color _electricBlue = Color(0xFF00B8FF);

  // ── tabs: Write | Reply
  late final TabController _tc = TabController(length: 2, vsync: this);

  // ── scroll (to auto-jump to result)
  final ScrollController _writeSC = ScrollController();
  final ScrollController _replySC = ScrollController();

  // ── inputs
  final TextEditingController _writeInput = TextEditingController(); // main input for "Write"
  final TextEditingController _replyInput = TextEditingController(); // guidance for "Reply" (optional)
  final TextEditingController _replyContext = TextEditingController(); // original content to reply
  final TextEditingController _learning = TextEditingController(); // style guardrails

  // ── result (separate per tab + editable)
  final TextEditingController _writeResultCtrl = TextEditingController();
  final TextEditingController _replyResultCtrl = TextEditingController();
  final FocusNode _writeResultFocus = FocusNode();
  final FocusNode _replyResultFocus = FocusNode();

  // ── options
  String _tone = 'Neutral';
  String _length = 'Medium';
  String _style = 'Professional';
  String _lang = 'English';
  ReplyState _replyState = ReplyState.none;

  // ── state
  bool _busy = false;

  @override
  void dispose() {
    _tc.dispose();
    _writeSC.dispose();
    _replySC.dispose();
    _writeInput.dispose();
    _replyInput.dispose();
    _replyContext.dispose();
    _learning.dispose();
    _writeResultCtrl.dispose();
    _replyResultCtrl.dispose();
    _writeResultFocus.dispose();
    _replyResultFocus.dispose();
    super.dispose();
  }

  // ─────────────────────────────── logic helpers ───────────────────────────────

  String _replyStateLabel(ReplyState s) {
    switch (s) {
      case ReplyState.none: return 'None';
      case ReplyState.interested: return 'Interested';
      case ReplyState.considering: return 'Considering';
      case ReplyState.notInterested: return 'Not interested';
      case ReplyState.needMoreInfo: return 'Need more info';
      case ReplyState.scheduleCall: return 'Schedule a call';
    }
  }

  String _replyStateHint(ReplyState s) {
    switch (s) {
      case ReplyState.none: return '';
      case ReplyState.interested:   return 'Be warm and appreciative. Confirm interest and propose clear next steps.';
      case ReplyState.considering:  return 'Be polite; ask 1–2 concise clarifying questions before proceeding.';
      case ReplyState.notInterested:return 'Decline kindly. Appreciate their outreach. Keep it short.';
      case ReplyState.needMoreInfo: return 'Ask for specific missing details as a neat bullet list.';
      case ReplyState.scheduleCall: return 'Suggest 2–3 time slots (with timezone) and ask for their preference.';
    }
  }

  Future<void> _pasteInto(TextEditingController ctrl) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = (data?.text ?? '').trim();
    if (t.isEmpty) return;
    ctrl.text = t;
    ctrl.selection = TextSelection.fromPosition(TextPosition(offset: t.length));
    setState(() {});
  }

  bool get _canGenerate {
    if (_tc.index == 0) {
      // Write tab requires main input
      return _writeInput.text.trim().isNotEmpty;
    } else {
      // Reply tab requires at least one of the fields
      return _replyInput.text.trim().isNotEmpty || _replyContext.text.trim().isNotEmpty;
    }
  }

  String _baseSystem() => '''
You write emails in the selected tone, length, style, and language.
Rules:
- If applicable, include a "Subject:" line, then the body.
- Keep it clear, specific, and human. No fluff.
- Respect the “Learning Resource” strictly if provided.
[mood: neutral]
''';

  String _systemForTab() {
    if (_tc.index == 0) return _baseSystem();
    return _baseSystem() + '\nThis is a reply. Infer context and keep thread continuity. Be polite.\n';
  }

  String _optionsLine() {
    final lr = _learning.text.trim();
    final lrPart = lr.isEmpty ? '' : ' | Learning Resource: $lr';
    return 'Tone: $_tone | Length: $_length | Style: $_style | Language: $_lang$lrPart';
  }

  String _composeUser() {
    if (_tc.index == 0) {
      return '''
Task: Write Email
Options: ${_optionsLine()}

Input:
${_writeInput.text.trim()}
''';
    } else {
      final rs = _replyState == ReplyState.none
          ? ''
          : '\nReply State: ${_replyStateLabel(_replyState)}\nGuidance: ${_replyStateHint(_replyState)}\n';
      final ctx = _replyContext.text.trim();
      final ctxBlock = ctx.isEmpty ? '' : '\nOriginal content to reply:\n$ctx\n';
      final guidance = _replyInput.text.trim();
      final guidanceBlock = guidance.isEmpty ? '' : '\nAdditional guidance (from user):\n$guidance\n';

      return '''
Task: Reply Email
Options: ${_optionsLine()}$rs$ctxBlock$guidanceBlock
''';
    }
  }

  Future<void> _generate() async {
    if (!_canGenerate || _busy) return;
    setState(() { _busy = true; });

    final sys = _systemForTab();
    final user = _composeUser();

    final ans = await GPMaiBrain.send(user, systemPrompt: sys);
    final text = ans.trim();

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_tc.index == 0) {
        _writeResultCtrl.text = text;
        _writeResultCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _writeResultCtrl.text.length));
        FocusScope.of(context).requestFocus(_writeResultFocus);
      } else {
        _replyResultCtrl.text = text;
        _replyResultCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _replyResultCtrl.text.length));
        FocusScope.of(context).requestFocus(_replyResultFocus);
      }
    });
    _scrollToResult();
  }

  void _openPreviewSheetWith(String t) {
    if (t.trim().isEmpty) return;

    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Preview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: SingleChildScrollView(child: SelectableText(t)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: t));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary, foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () { Share.share(t); Navigator.pop(ctx); },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToResult() {
    final sc = _tc.index == 0 ? _writeSC : _replySC;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!sc.hasClients) return;
      sc.animateTo(
        sc.position.maxScrollExtent + 160,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ─────────────────────────────── UI helpers ───────────────────────────────

  List<BoxShadow> _softShadow(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return isDark
        ? [BoxShadow(color: Colors.black.withOpacity(.40), blurRadius: 18, offset: const Offset(0, 10))]
        : [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 22, offset: const Offset(0, 10))];
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    Color? accent,
    EdgeInsetsGeometry? padding,
  }) {
    final cs = Theme.of(context).colorScheme;
    final ac = accent ?? _electricBlue;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(.18)),
        boxShadow: _softShadow(context),
      ),
      child: Stack(
        children: [
          // subtle accent stripe
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: ac.withOpacity(.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface.withOpacity(.94))),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? _electricBlue : cs.surfaceVariant.withOpacity(.22);
    final fg = selected ? Colors.black : cs.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _electricBlue : cs.outline.withOpacity(.3)),
        ),
        child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _chipGroup({
    required String label,
    required List<String> values,
    required String current,
    required void Function(String) onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map((v) => _pillChip(label: v, selected: v == current, onTap: () => onPick(v)))
              .toList(),
        ),
      ],
    );
  }

  Widget _languageRow() {
    final languages = <String>[
      'English','Hindi','Malayalam','Tamil','Telugu','Kannada','Bengali','Marathi','Gujarati','Punjabi',
      'Spanish','French','German','Arabic','Turkish','Portuguese','Russian',
      'Japanese','Korean','Chinese (Simplified)','Chinese (Traditional)','Italian','Indonesian','Vietnamese','Thai'
    ];
    return Row(
      children: [
        const Icon(Icons.flag_rounded, size: 18),
        const SizedBox(width: 8),
        const Text('Output language:'),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _lang,
          items: languages.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
          onChanged: (v) => setState(() => _lang = v ?? 'English'),
        ),
      ],
    );
  }

  InputDecoration _bigInputDecoration({
    required String hint,
    TextEditingController? controller,
    IconData icon = Icons.edit_note_rounded,
    Color accent = _electricBlue,
    bool showPaste = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: accent),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: cs.surfaceVariant.withOpacity(.16),
      suffixIcon: showPaste
          ? IconButton(
              tooltip: 'Paste',
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: () => _pasteInto(controller!),
            )
          : null,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _electricBlue, width: 2),
      ),
    );
  }

  // ─────────────────────────────── Result card (editable) ───────────────────────────────

  Widget _resultCard({
    required String title,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Color accent,
  }) {
    final cs = Theme.of(context).colorScheme;

    Future<void> _copy() async {
      final t = controller.text.trim();
      if (t.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: t));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
      }
    }

    Future<void> _share() async {
      final t = controller.text.trim();
      if (t.isEmpty) return;
      await Share.share(t);
    }

    void _preview() => _openPreviewSheetWith(controller.text);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(controller.text.hashCode ^ accent.value),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(.18)),
          gradient: LinearGradient(
            colors: [accent.withOpacity(.12), cs.surfaceVariant.withOpacity(.10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: _softShadow(context),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                    IconButton(tooltip: 'Preview', onPressed: _preview, icon: const Icon(Icons.open_in_full_rounded)),
                    IconButton(tooltip: 'Copy',    onPressed: _copy,    icon: const Icon(Icons.copy_rounded)),
                    IconButton(tooltip: 'Share',   onPressed: _share,   icon: const Icon(Icons.ios_share_rounded)),
                  ]),
                  const SizedBox(height: 6),
                  // Editable result
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: null,
                    minLines: 8,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────── tabs ──────────────────────────────────

  Widget _writeTab() {
    return ListView(
      controller: _writeSC,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // bottom pad for sticky bar
      children: [
        _sectionCard(
          title: 'What should I write?',
          children: [
            TextField(
              controller: _writeInput,
              maxLines: 8,
              decoration: _bigInputDecoration(
                hint: 'e.g., “Thank the customer for their recent purchase, offer help if needed…”',
                controller: _writeInput,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Text Preferences',
          children: [
            _chipGroup(
              label: 'Tone',
              values: const ['Neutral','Friendly','Formal','Casual','Persuasive'],
              current: _tone,
              onPick: (v) => setState(() => _tone = v),
            ),
            const SizedBox(height: 12),
            _chipGroup(
              label: 'Length',
              values: const ['Very short','Short','Medium','Long'],
              current: _length,
              onPick: (v) => setState(() => _length = v),
            ),
            const SizedBox(height: 12),
            _chipGroup(
              label: 'Style',
              values: const ['Professional','Direct','Warm','Detailed'],
              current: _style,
              onPick: (v) => setState(() => _style = v),
            ),
            const SizedBox(height: 12),
            _languageRow(),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Learning Resource (optional)',
          children: [
            TextField(
              controller: _learning,
              decoration: const InputDecoration(
                labelText: 'Style guide / constraints',
                hintText: 'e.g., Use plain language and short paragraphs',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_writeResultCtrl.text.isNotEmpty)
          _resultCard(
            title: 'Result (Write)',
            controller: _writeResultCtrl,
            focusNode: _writeResultFocus,
            accent: const Color(0xFF7E57C2), // purple
          ),
      ],
    );
  }

  Widget _replyTab() {
    return ListView(
      controller: _replySC,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // bottom pad for sticky bar
      children: [
        _sectionCard(
          title: 'Step 1 — Paste the email you’re replying to',
          accent: const Color(0xFF6EE7B7), // green
          children: [
            TextField(
              controller: _replyContext,
              maxLines: 8,
              decoration: _bigInputDecoration(
                hint: 'Paste the original email/message here',
                controller: _replyContext,
                icon: Icons.mail_outline_rounded,
                accent: const Color(0xFF6EE7B7),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text('Tip: include only the relevant part of the thread.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(.7), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Step 2 — What should the reply say? (optional)',
          accent: const Color(0xFFFFD54F), // yellow
          children: [
            TextField(
              controller: _replyInput,
              maxLines: 5,
              decoration: _bigInputDecoration(
                hint: 'Add guidance or key points (optional)',
                controller: _replyInput,
                icon: Icons.tips_and_updates_rounded,
                accent: const Color(0xFFFFD54F),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Quick response state',
          children: [
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ReplyState.values.map((s) {
                final lbl = _replyStateLabel(s);
                return _pillChip(
                  label: lbl,
                  selected: _replyState == s,
                  onTap: () => setState(() => _replyState = s),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Text Preferences',
          children: [
            _chipGroup(
              label: 'Tone',
              values: const ['Neutral','Friendly','Formal','Casual','Persuasive'],
              current: _tone,
              onPick: (v) => setState(() => _tone = v),
            ),
            const SizedBox(height: 12),
            _chipGroup(
              label: 'Length',
              values: const ['Very short','Short','Medium','Long'],
              current: _length,
              onPick: (v) => setState(() => _length = v),
            ),
            const SizedBox(height: 12),
            _chipGroup(
              label: 'Style',
              values: const ['Professional','Direct','Warm','Detailed'],
              current: _style,
              onPick: (v) => setState(() => _style = v),
            ),
            const SizedBox(height: 12),
            _languageRow(),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Learning Resource (optional)',
          children: [
            TextField(
              controller: _learning,
              decoration: const InputDecoration(
                labelText: 'Style guide / constraints',
                hintText: 'e.g., Keep it very concise and action-oriented',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_replyResultCtrl.text.isNotEmpty)
          _resultCard(
            title: 'Result (Reply)',
            controller: _replyResultCtrl,
            focusNode: _replyResultFocus,
            accent: const Color(0xFF26C6DA), // teal
          ),
      ],
    );
  }

  // sticky bottom generate bar
  Widget _bottomBar() {
    final cs = Theme.of(context).colorScheme;
    final enabled = _canGenerate && !_busy;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: cs.outline.withOpacity(.2))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: enabled ? _generate : null,
                icon: _busy
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_busy ? 'Generating...' : 'Generate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: enabled || _busy ? _electricBlue : cs.surfaceVariant,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────── build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Email Writer'),
        bottom: TabBar(
          controller: _tc,
          tabs: const [Tab(text: 'Write'), Tab(text: 'Reply')],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          _writeTab(),
          _replyTab(),
        ],
      ),
      bottomNavigationBar: _bottomBar(), // sticky CTA with spinner
    );
  }
}
