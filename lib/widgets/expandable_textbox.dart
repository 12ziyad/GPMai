import 'package:flutter/material.dart';

class ExpandableTextBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isLight;
  final Color borderColor;
  final Widget attachmentPreview;
  final ValueChanged<String> onExpandSend;
  final String? hintText;

  const ExpandableTextBox({
    super.key,
    required this.controller,
    this.focusNode,
    required this.isLight,
    required this.borderColor,
    required this.attachmentPreview,
    required this.onExpandSend,
    this.hintText,
  });

  @override
  State<ExpandableTextBox> createState() => _ExpandableTextBoxState();
}

class _ExpandableTextBoxState extends State<ExpandableTextBox> {
  Future<void> _openLongComposer() async {
    final initial = widget.controller.text;
    final result = await showModalBottomSheet<_LongComposerResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _LongComposer(initial: initial),
    );

    if (result == null) return;
    if (result.action == _LongAction.insert) {
      widget.controller.text = result.text;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.controller.text.length),
      );
      setState(() {});
    } else if (result.action == _LongAction.send) {
      widget.onExpandSend(result.text);
    }
  }

  int _wrappedLineCount({
    required String text,
    required double maxWidth,
    required TextStyle style,
  }) {
    // Avoid zero-width layout.
    final width = maxWidth <= 0 ? 1.0 : maxWidth;

    final tp = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      maxLines: null,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: width);
    return tp.computeLineMetrics().length;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.isLight;
    final borderColor = widget.borderColor;
    final textStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 16);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        return AnimatedBuilder(
          animation: widget.controller,
          builder: (_, __) {
            // Approximate inner width: container padding (8+8) + TextField contentPadding (8+8)
            final innerWidth = constraints.maxWidth - 32.0;
            final lineCount = _wrappedLineCount(
              text: widget.controller.text,
              maxWidth: innerWidth,
              style: textStyle,
            );
            final showExpand = lineCount >= 3; // => reached start of 3rd line

            return Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(
                color: isLight ? Colors.white10 : const Color(0xFF151920),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor.withOpacity(.35)),
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.attachmentPreview,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              style: textStyle,
                              maxLines: 6,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline, // Enter => newline
                              decoration: InputDecoration(
                                hintText: widget.hintText ?? "Type your message…",
                                isCollapsed: true,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Small, non-pulsing icon (top-right of the input box)
                  if (showExpand)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openLongComposer,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(isLight ? .08 : .18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.unfold_more_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/* ── long composer sheet ── */

enum _LongAction { insert, send }

class _LongComposerResult {
  final _LongAction action;
  final String text;
  const _LongComposerResult(this.action, this.text);
}

class _LongComposer extends StatefulWidget {
  final String initial;
  const _LongComposer({required this.initial, super.key});

  @override
  State<_LongComposer> createState() => _LongComposerState();
}

class _LongComposerState extends State<_LongComposer> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Write a longer message",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: TextField(
              controller: _c,
              autofocus: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: "Type your full paragraph…",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${_c.text.length} chars",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  _LongComposerResult(_LongAction.insert, _c.text),
                ),
                child: const Text("Insert"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  _LongComposerResult(_LongAction.send, _c.text),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text("Send"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
