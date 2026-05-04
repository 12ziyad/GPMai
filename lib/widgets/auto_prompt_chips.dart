import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/gpmai_api_client.dart';

class AutoPromptChips extends StatefulWidget {
  final TextEditingController controller;
  final String screenContext;
  final Future<void> Function(String transformedText, String chipType, String chipLabel) onSend;

  const AutoPromptChips({
    super.key,
    required this.controller,
    required this.screenContext,
    required this.onSend,
  });

  @override
  State<AutoPromptChips> createState() => _AutoPromptChipsState();
}

class _AutoPromptChipsState extends State<AutoPromptChips> {
  Timer? _debounce;
  final ScrollController _previewScrollCtrl = ScrollController();
  final GlobalKey _afterKey = GlobalKey();

  int _score = 0;
  int _qualityBars = 1;
  bool _expanded = true;
  bool _busy = false;
  bool _showJumpToAfter = false;
  String? _activeChipType;
  String? _activeChipLabel;
  String? _originalText;
  String? _transformedText;
  String? _error;
  String? _helperNote;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _previewScrollCtrl.addListener(_onPreviewScroll);
    _recomputeQuality();
  }

  @override
  void didUpdateWidget(covariant AutoPromptChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _recomputeQuality();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _previewScrollCtrl.removeListener(_onPreviewScroll);
    _previewScrollCtrl.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _recomputeQuality);

    final current = widget.controller.text.trim();
    if (current.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = null;
        _activeChipType = null;
        _activeChipLabel = null;
        _originalText = null;
        _transformedText = null;
        _helperNote = null;
        _showJumpToAfter = false;
      });
      return;
    }

    if (_originalText != null && current != (_originalText ?? '').trim()) {
      if (!mounted) return;
      setState(() {
        _activeChipType = null;
        _activeChipLabel = null;
        _originalText = null;
        _transformedText = null;
        _error = null;
        _helperNote = null;
        _showJumpToAfter = false;
      });
    }
  }

  void _onPreviewScroll() {
    _syncJumpToAfterVisibility();
  }

  void _syncJumpToAfterVisibility() {
    if (!_previewScrollCtrl.hasClients) {
      if (_showJumpToAfter && mounted) {
        setState(() => _showJumpToAfter = false);
      }
      return;
    }

    final position = _previewScrollCtrl.position;
    final hasMeaningfulOverflow = position.maxScrollExtent > 56;
    final shouldShow = hasMeaningfulOverflow && position.pixels < math.min(120, position.maxScrollExtent * .60);

    if (shouldShow != _showJumpToAfter && mounted) {
      setState(() => _showJumpToAfter = shouldShow);
    }
  }

  void _recomputeQuality() {
    final text = widget.controller.text.trim();
    final score = _computeQualityScore(text);
    if (!mounted) return;
    setState(() {
      _score = score;
      _qualityBars = _mapBars(score);
      if (text.isNotEmpty && _activeChipType == null) {
        _expanded = true;
      }
    });
  }

  int _computeQualityScore(String text) {
    if (text.isEmpty) return 0;
    int score = 0;
    final lower = text.toLowerCase();
    if (text.length > 8) score += 10;
    if (text.length > 25) score += 10;
    if (text.length > 55) score += 10;
    if (text.contains('?')) score += 8;
    if (text.isNotEmpty && text[0].toUpperCase() == text[0] && RegExp(r'[A-Z]').hasMatch(text[0])) {
      score += 8;
    }
    if (!RegExp(r'\b(fater|shud|wat|gonna|wanna|pls)\b').hasMatch(lower)) score += 15;
    if (RegExp(r'\b(analyze|compare|explain|what|how|why|should|best|difference|specific|detail|improve)\b').hasMatch(lower)) {
      score += 14;
    }
    if (RegExp(r'\b(my|our|team|startup|app|product|flutter|code)\b').hasMatch(lower)) score += 10;
    if (RegExp(r'\[[^\]]+\]').hasMatch(text)) score += 15;
    return score.clamp(0, 100);
  }

  int _mapBars(int score) {
    if (score <= 19) return 1;
    if (score <= 34) return 2;
    if (score <= 54) return 3;
    if (score <= 74) return 4;
    return 5;
  }

  Color _barColor(int bars) {
    switch (bars) {
      case 1:
        return const Color(0xFFFF6B6B);
      case 2:
        return const Color(0xFFFFB347);
      case 3:
        return const Color(0xFFFFE066);
      case 4:
        return const Color(0xFF5EE89C);
      default:
        return const Color(0xFF9E7BFF);
    }
  }

  ({String label1, String label2, String type1, String type2}) _chipConfig() {
    switch (widget.screenContext.trim().toLowerCase()) {
      case 'debate':
        return (label1: 'Fix and Send', label2: 'Run as Debate', type1: 'fix_send', type2: 'run_debate');
      case 'canvas':
        return (label1: 'Fix and Send', label2: 'Add to Canvas Section', type1: 'fix_send', type2: 'canvas_section');
      case 'map':
        return (label1: 'Fix and Send', label2: 'Make It Detailed', type1: 'fix_send', type2: 'research_mode');
      case 'chat':
      default:
        return (label1: 'Fix and Send', label2: 'Make It Detailed', type1: 'fix_send', type2: 'research_mode');
    }
  }

  bool _startsWithAny(String lower, List<String> starters) {
    for (final starter in starters) {
      if (lower.startsWith(starter)) return true;
    }
    return false;
  }

  bool _looksBadTransform(String transformed, String label, String original) {
    final t = transformed.trim();
    final lower = t.toLowerCase();
    final originalLower = original.trim().toLowerCase();
    if (t.isEmpty) return true;

    const badExact = <String>{
      'fix and send',
      'research mode',
      'make it detailed',
      'run as debate',
      'add to canvas section',
      'map context',
    };
    if (badExact.contains(lower)) return true;
    if (lower == label.trim().toLowerCase()) return true;
    if (original.trim().isNotEmpty && lower.length <= 3 && original.trim().length > 3) return true;

    const hardLeakPatterns = <String>[
      'please rewrite the following prompt',
      'rewrite the full prompt',
      'rewrite only the provided prompt sections',
      'return only the improved final prompt',
      'return only valid json',
      'return json only',
      'return plain text only',
      'do not include markdown fences',
      'do not include any ids that were not provided',
      'for the "fix and send" chip',
      'for the fix and send chip',
      'for the chat screen',
      'you improve user prompts',
      'you are handling the',
      'app called gpmai',
      '[explanation to improve]',
      '[attached raw content to keep unchanged]',
      '"rewritten"',
      '{"rewritten"',
    ];
    for (final bad in hardLeakPatterns) {
      if (lower.contains(bad)) return true;
    }

    final assistantLike = _startsWithAny(lower, const [
      'sure,',
      'sure —',
      'sure!',
      'here is',
      'here’s',
      'i can help',
      'i can definitely help',
      'please provide',
      'to help you',
      'i need more',
      'once i have',
      'what made you ask',
      'the answer is',
      'you should',
      'let me help',
    ]);

    if (assistantLike && !originalLower.startsWith(lower.substring(0, math.min(lower.length, 12)))) {
      return true;
    }

    final metaFirstLine = t.split('\n').first.trim().toLowerCase();
    if (metaFirstLine.endsWith(':') &&
        (metaFirstLine.contains('improved prompt') ||
            metaFirstLine.contains('rewritten prompt') ||
            metaFirstLine.contains('fixed prompt') ||
            metaFirstLine.contains('transformed prompt'))) {
      return true;
    }

    return false;
  }

  String? _helperNoteFor({
    required String rewriteMode,
    required int lineCount,
    required int charCount,
  }) {
    if (rewriteMode == 'smart_patch') {
      return 'Large input detected • improved the request and preserved pasted content.';
    }
    if (lineCount > 80 || charCount > 5000) {
      return 'Large input processed safely.';
    }
    return null;
  }

  Future<void> _runChip(String chipType, String chipLabel) async {
    final input = widget.controller.text.trim();
    if (input.isEmpty || _busy) return;

    FocusScope.of(context).unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    setState(() {
      _busy = true;
      _error = null;
      _activeChipType = chipType;
      _activeChipLabel = chipLabel;
      _helperNote = null;
      _showJumpToAfter = false;
    });

    try {
      final res = await GpmaiApiClient.promptChips(
        inputText: input,
        screenContext: widget.screenContext,
        chipType: chipType,
      );

      final transformed = (res['transformedText'] ?? '').toString().trim();
      final metrics = (res['inputMetrics'] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
      if (_looksBadTransform(transformed, chipLabel, input)) {
        throw Exception('invalid transform');
      }

      final lineCount = (metrics?['lineCount'] as num?)?.toInt() ?? 0;
      final charCount = (metrics?['charCount'] as num?)?.toInt() ?? 0;
      final rewriteMode = (res['rewriteMode'] ?? '').toString();

      setState(() {
        _expanded = true;
        _originalText = input;
        _transformedText = transformed;
        _helperNote = _helperNoteFor(
          rewriteMode: rewriteMode,
          lineCount: lineCount,
          charCount: charCount,
        );
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_previewScrollCtrl.hasClients) return;
        _previewScrollCtrl.jumpTo(0);
        _syncJumpToAfterVisibility();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not build a clean rewrite right now.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _jumpToAfter() async {
    final ctx = _afterKey.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
    if (mounted) setState(() => _showJumpToAfter = false);
  }

  Widget _buildBar(int index, Color color) {
    final active = index < _qualityBars;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active ? color : Colors.white.withOpacity(.10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withOpacity(.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  double _previewBoxHeight(MediaQueryData media) {
    final keyboardOpen = media.viewInsets.bottom > 0;
    final visibleHeight = math.max(
      220.0,
      media.size.height - media.viewInsets.bottom - media.padding.top - media.padding.bottom,
    );

    if (keyboardOpen) {
      return math.min(148.0, math.max(116.0, visibleHeight * .22));
    }
    return math.min(320.0, math.max(228.0, visibleHeight * .34));
  }

  double _actionBarHeight(bool keyboardOpen) => keyboardOpen ? 58 : 68;

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final config = _chipConfig();
    final barColor = _barColor(_qualityBars);
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final previewBoxHeight = _previewBoxHeight(media);
    final actionBarHeight = _actionBarHeight(keyboardOpen);
    final previewBottomPadding = actionBarHeight + (keyboardOpen ? 12 : 18);
    final hasPreview = _originalText != null && _transformedText != null;

    Widget chipButton(String label, String type, List<Color> colors) {
      final selected = _activeChipType == type;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : () => _runChip(type, label),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: keyboardOpen ? 11 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: colors),
              border: Border.all(
                color: selected ? Colors.white.withOpacity(.40) : Colors.white.withOpacity(.16),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withOpacity(.24),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_busy && selected)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(
                    type == 'fix_send' ? Icons.auto_fix_high_rounded : Icons.subject_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF121826), Color(0xFF0B1020)],
          ),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, keyboardOpen ? 10 : 12, 14, keyboardOpen ? 10 : 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Prompt helper',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(.92),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_score/100',
                                style: TextStyle(color: barColor, fontWeight: FontWeight.w900, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(children: List.generate(5, (index) => _buildBar(index, barColor))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_expanded
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, keyboardOpen ? 10 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              chipButton(config.label1, config.type1, const [Color(0xFF12C6FF), Color(0xFF3C7CFF)]),
                              const SizedBox(width: 10),
                              chipButton(config.label2, config.type2, const [Color(0xFF8D63FF), Color(0xFF5B35E4)]),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFFF8A8A), fontWeight: FontWeight.w700),
                            ),
                          ],
                          if (hasPreview) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: previewBoxHeight,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.03),
                                    border: Border.all(color: Colors.white.withOpacity(.08)),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Scrollbar(
                                          controller: _previewScrollCtrl,
                                          thumbVisibility: false,
                                          child: SingleChildScrollView(
                                            controller: _previewScrollCtrl,
                                            physics: const ClampingScrollPhysics(),
                                            padding: EdgeInsets.fromLTRB(14, 14, 14, previewBottomPadding),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Expanded(
                                                      child: Text(
                                                        'Preview',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 18,
                                                        ),
                                                      ),
                                                    ),
                                                    if (_showJumpToAfter)
                                                      Material(
                                                        color: Colors.transparent,
                                                        child: InkWell(
                                                          borderRadius: BorderRadius.circular(999),
                                                          onTap: _jumpToAfter,
                                                          child: Container(
                                                            padding: const EdgeInsets.all(6),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: Colors.white.withOpacity(.06),
                                                              border: Border.all(
                                                                color: Colors.white.withOpacity(.10),
                                                              ),
                                                            ),
                                                            child: const Icon(
                                                              Icons.keyboard_double_arrow_down_rounded,
                                                              color: Colors.white,
                                                              size: 18,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (_helperNote != null) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _helperNote!,
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(.70),
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 12),
                                                const Text(
                                                  'BEFORE',
                                                  style: TextStyle(
                                                    color: Color(0xFFFF8A8A),
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                SelectableText(
                                                  _originalText!,
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(.74),
                                                    height: 1.45,
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationColor: Colors.white.withOpacity(.65),
                                                  ),
                                                ),
                                                const SizedBox(height: 18),
                                                KeyedSubtree(
                                                  key: _afterKey,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text(
                                                        'AFTER',
                                                        style: TextStyle(
                                                          color: Color(0xFFFFE066),
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      SelectableText(
                                                        _transformedText!,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w800,
                                                          height: 1.45,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          height: actionBarHeight,
                                          padding: EdgeInsets.fromLTRB(14, keyboardOpen ? 8 : 10, 14, keyboardOpen ? 10 : 14),
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                                            color: const Color(0xFF0F1523).withOpacity(.96),
                                            border: Border(
                                              top: BorderSide(color: Colors.white.withOpacity(.08)),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: SizedBox(
                                                  height: keyboardOpen ? 40 : 44,
                                                  child: FilledButton.icon(
                                                    onPressed: _busy
                                                        ? null
                                                        : () async {
                                                            final transformed = _transformedText;
                                                            final chipType = _activeChipType;
                                                            final chipLabel = _activeChipLabel;
                                                            if (transformed == null || chipType == null || chipLabel == null) {
                                                              return;
                                                            }
                                                            await widget.onSend(transformed, chipType, chipLabel);
                                                            if (!mounted) return;
                                                            setState(() {
                                                              _expanded = false;
                                                              _originalText = null;
                                                              _transformedText = null;
                                                              _helperNote = null;
                                                              _showJumpToAfter = false;
                                                            });
                                                          },
                                                    icon: const Icon(Icons.send_rounded),
                                                    label: const FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text('Send this prompt'),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                height: keyboardOpen ? 40 : 44,
                                                child: OutlinedButton(
                                                  onPressed: () {
                                                    final next = _transformedText;
                                                    if (next == null) return;
                                                    widget.controller.value = TextEditingValue(
                                                      text: next,
                                                      selection: TextSelection.collapsed(offset: next.length),
                                                    );
                                                    setState(() {
                                                      _originalText = null;
                                                      _transformedText = null;
                                                      _helperNote = null;
                                                      _showJumpToAfter = false;
                                                    });
                                                  },
                                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                                                  child: const Text('Edit'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
