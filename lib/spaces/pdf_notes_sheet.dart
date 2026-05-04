import 'package:flutter/material.dart';
import '../services/gpmai_brain.dart';

class PdfNotesSheet extends StatefulWidget {
  final String initial;
  /// Hidden context used only for answers (Key points + Summary).
  final String summaryForQA;
  /// 0 = Notes (default), 1 = Ask
  final int initialPage;

  const PdfNotesSheet({
    super.key,
    required this.initial,
    required this.summaryForQA,
    this.initialPage = 0,
  });

  @override
  State<PdfNotesSheet> createState() => _PdfNotesSheetState();
}

class _PdfNotesSheetState extends State<PdfNotesSheet> {
  late final PageController _pageCtrl =
      PageController(initialPage: widget.initialPage);
  int _page = 0;

  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initial);
  final TextEditingController _askCtrl = TextEditingController();
  final FocusNode _noteFocus = FocusNode();

  String? _answer;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _noteFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _noteCtrl.dispose();
    _askCtrl.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = _askCtrl.text.trim();
    if (q.isEmpty || _asking) return;
    setState(() => _asking = true);
    try {
      final sys = '''
You answer questions about a single PDF. Use only the provided key points and summary.
Be concise. Do not dump or re-summarize unless needed to answer.
[mood: neutral]
''';
      final user = 'Context (key points & summary):\n${widget.summaryForQA}\n\nQuestion: $q';
      final resp = await GPMaiBrain.send(user, systemPrompt: sys);
      if (!mounted) return;
      setState(() => _answer = resp.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() => _answer = 'Error: $e');
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FractionallySizedBox(
      heightFactor: .9, // 90% height
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                // Header (left-shifted so orb won’t cover)
                Padding(
                  padding: const EdgeInsets.only(right: 56),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context, null),
                          tooltip: 'Close',
                        ),
                      ),
                      Text(
                        _page == 0 ? 'Add note' : 'Ask about PDF',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        // <-- replaced tick icon with a clear Save button
                        child: _page == 0
                            ? TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, _noteCtrl.text.trim()),
                                child: const Text('Save'),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                // Pager indicator
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (i) {
                      final active = _page == i;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: active ? 22 : 6,
                        decoration: BoxDecoration(
                          color: active ? cs.primary : cs.onSurface.withOpacity(.35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      // ── Page 1: Notes ──
                      Stack(
                        children: [
                          TextField(
                            controller: _noteCtrl,
                            focusNode: _noteFocus,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top, // caret on top
                            decoration: InputDecoration(
                              hintText: 'Tap to start writing…',
                              filled: true,
                              contentPadding: const EdgeInsets.all(14),
                              fillColor: cs.surfaceVariant.withOpacity(.18),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          // centered swipe hint overlay (vanishes on focus or typing)
                          if (!_noteFocus.hasFocus && _noteCtrl.text.trim().isEmpty)
                            IgnorePointer(
                              child: Center(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cs.surface.withOpacity(.8),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: cs.onSurface.withOpacity(.15)),
                                  ),
                                  child: const Text('Swipe → to ask about this PDF'),
                                ),
                              ),
                            ),
                        ],
                      ),

                      // ── Page 2: Ask ──
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Ask about this PDF',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _askCtrl,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _ask(),
                            minLines: 2,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Type your question…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _asking ? null : _ask,
                              child: _asking
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Ask'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.surfaceVariant.withOpacity(.16),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cs.onSurface.withOpacity(.12)),
                              ),
                              child: _answer == null
                                  ? const Text('Your answer will appear here.',
                                      style: TextStyle(height: 1.35))
                                  : SingleChildScrollView(
                                      child:
                                          Text(_answer!, style: const TextStyle(height: 1.35)),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Swipe hint footer
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _page == 0 ? 'Swipe → to ask about this PDF' : 'Swipe ← to return to notes',
                    style: TextStyle(color: cs.onSurface.withOpacity(.6), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
