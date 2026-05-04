import 'package:flutter/material.dart';

import '../services/research_canvas_store.dart';

class SaveToCanvasSheet extends StatefulWidget {
  final ResearchCanvasBlockDraft draft;

  const SaveToCanvasSheet({super.key, required this.draft});

  static Future<void> open(BuildContext context, {required ResearchCanvasBlockDraft draft}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaveToCanvasSheet(draft: draft),
    );
  }

  @override
  State<SaveToCanvasSheet> createState() => _SaveToCanvasSheetState();
}

class _SaveToCanvasSheetState extends State<SaveToCanvasSheet> {
  final ResearchCanvasStore _store = ResearchCanvasStore();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _tagsCtrl = TextEditingController();
  bool _loading = true;
  bool _creating = true;
  bool _saving = false;
  List<ResearchCanvas> _canvases = const <ResearchCanvas>[];
  String? _selectedCanvasId;
  String _themeKey = 'aurora';

  String _cleanMetaText(String? raw) {
    final source = (raw ?? '').trim();
    if (source.isEmpty) return '';
    if (source.contains('<<META>>') && source.contains('<<ENDMETA>>')) {
      final start = source.indexOf('<<META>>');
      final end = source.indexOf('<<ENDMETA>>');
      final before = source.substring(0, start).trim();
      final after = source.substring(end + '<<ENDMETA>>'.length).trim();
      final merged = [before, after].where((e) => e.isNotEmpty).join(' ');
      if (merged.isNotEmpty) return merged.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    if (source.startsWith('<<META>>')) {
      final close = source.indexOf('}');
      if (close != -1 && close + 1 < source.length) {
        return source.substring(close + 1).replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return source.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _shorten(String value, {int max = 72}) {
    final clean = _cleanMetaText(value);
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max)}…';
  }

  String _defaultCanvasTitle() {
    final preferred = _cleanMetaText(widget.draft.title);
    if (preferred.isNotEmpty) return _shorten(preferred);
    final question = _cleanMetaText(widget.draft.question);
    if (question.isNotEmpty) return _shorten(question);
    final content = _cleanMetaText(widget.draft.content);
    if (content.isNotEmpty) return _shorten(content);
    return 'New research canvas';
  }


  @override
  void initState() {
    super.initState();
    _titleCtrl.text = _defaultCanvasTitle();
    final suggestedTags = widget.draft.tags.isEmpty
        ? ResearchCanvasStore.suggestTags(title: widget.draft.title, content: widget.draft.content, sourceLabel: widget.draft.sourceLabel, type: widget.draft.type)
        : widget.draft.tags;
    _tagsCtrl.text = suggestedTags.join(' ');
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final canvases = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _canvases = canvases;
      _selectedCanvasId = canvases.isEmpty ? null : canvases.first.id;
      _creating = canvases.isEmpty;
      _loading = false;
    });
  }

  void _autoFillTags() {
    final tags = ResearchCanvasStore.suggestTags(
      title: _titleCtrl.text,
      content: widget.draft.content,
      sourceLabel: widget.draft.sourceLabel,
      type: widget.draft.type,
    );
    setState(() => _tagsCtrl.text = tags.join(' '));
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final tags = ResearchCanvasStore.parseTags(_tagsCtrl.text);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      if (_creating) {
        final title = _titleCtrl.text.trim().isEmpty ? _defaultCanvasTitle() : _cleanMetaText(_titleCtrl.text);
        final canvas = await _store.createCanvas(
          title: title.isEmpty ? 'Untitled canvas' : title,
          tags: tags,
          themeKey: _themeKey,
          blocks: <ResearchCanvasBlock>[
            widget.draft.copyWith(
              title: _cleanMetaText(widget.draft.title).isEmpty ? title : _cleanMetaText(widget.draft.title),
              question: () {
                final cleanQuestion = _cleanMetaText(widget.draft.question);
                return cleanQuestion.isEmpty ? null : cleanQuestion;
              },
              content: _cleanMetaText(widget.draft.content),
              tags: tags,
            ).createBlock(),
          ],
        );
        _selectedCanvasId = canvas.id;
      } else if (_selectedCanvasId != null) {
        await _store.addDraftToCanvas(
          _selectedCanvasId!,
          widget.draft.copyWith(
            title: _cleanMetaText(widget.draft.title),
            question: () {
              final cleanQuestion = _cleanMetaText(widget.draft.question);
              return cleanQuestion.isEmpty ? null : cleanQuestion;
            },
            content: _cleanMetaText(widget.draft.content),
            tags: tags,
          ),
        );
      } else {
        messenger?.showSnackBar(const SnackBar(content: Text('Choose a canvas first.')));
        return;
      }
      if (!mounted) return;
      navigator.pop(true);
      messenger?.showSnackBar(
        SnackBar(content: Text(_creating ? 'Saved into new canvas ✨' : 'Added to canvas ✨')),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Could not save to Canvas: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? const Color(0xFFF7F9FC) : const Color(0xFF0A0D14);
    final text = isLight ? Colors.black87 : Colors.white;
    final sub = isLight ? Colors.black54 : Colors.white70;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.9),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isLight
                  ? const [Color(0xFFF9FBFF), Color(0xFFF0F4FB), Color(0xFFEAF0F9)]
                  : const [Color(0xFF11192A), Color(0xFF191226), Color(0xFF090B11)],
            ),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 16))],
          ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: _loading
                    ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
                    : Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 78),
                            child: SingleChildScrollView(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                      Text('Add to Research Canvas', style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        'Save this answer into a premium workspace so you can grow it later with notes, tags, and AI sections.',
                        style: TextStyle(color: sub, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _ModePill(
                              label: 'New canvas',
                              selected: _creating,
                              onTap: () => setState(() => _creating = true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ModePill(
                              label: 'Existing',
                              selected: !_creating,
                              onTap: _canvases.isEmpty ? null : () => setState(() => _creating = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_creating) ...[
                        _PrettyField(
                          controller: _titleCtrl,
                          label: 'Canvas title',
                          hint: 'Startup research board',
                        ),
                        const SizedBox(height: 12),
                        Text('Theme mood', style: TextStyle(color: text, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const <MapEntry<String, String>>[
                            MapEntry('aurora', 'Aurora'),
                            MapEntry('rose', 'Rose'),
                            MapEntry('mint', 'Mint'),
                            MapEntry('ember', 'Ember'),
                          ].map((entry) {
                            final selected = _themeKey == entry.key;
                            return _ThemePill(
                              themeKey: entry.key,
                              label: entry.value,
                              selected: selected,
                              onTap: () => setState(() => _themeKey = entry.key),
                            );
                          }).toList(),
                        ),
                      ] else ...[
                        Text('Choose canvas', style: TextStyle(color: text, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        if (_canvases.isEmpty)
                          Text('No existing canvases yet.', style: TextStyle(color: sub))
                        else
                          SizedBox(
                            height: 180,
                            child: ListView.separated(
                              itemCount: _canvases.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, index) {
                                final canvas = _canvases[index];
                                final selected = canvas.id == _selectedCanvasId;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => setState(() => _selectedCanvasId = canvas.id),
                                  child: Ink(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      color: selected
                                          ? (isLight ? const Color(0xFFEAF1FF) : Colors.white.withOpacity(.08))
                                          : (isLight ? Colors.white : Colors.white.withOpacity(.04)),
                                      border: Border.all(
                                        color: selected ? const Color(0xFF4B8EFF) : (isLight ? Colors.black12 : Colors.white12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.auto_awesome_mosaic_rounded, color: selected ? const Color(0xFF4B8EFF) : sub),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(canvas.title, style: TextStyle(color: text, fontWeight: FontWeight.w800)),
                                              const SizedBox(height: 4),
                                              Text('${canvas.blocks.length} blocks', style: TextStyle(color: sub, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        if (selected) const Icon(Icons.check_circle_rounded, color: Color(0xFF4B8EFF)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PrettyField(
                              controller: _tagsCtrl,
                              label: 'Hashtags',
                              hint: '#startup #pricing #launch',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: OutlinedButton.icon(
                              onPressed: _autoFillTags,
                              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                              label: const Text('Auto'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 90),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(colors: [Color(0xFF13C7FF), Color(0xFF8D63FF), Color(0xFFFF5B93)]),
                                ),
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.library_add_rounded),
                                  label: Text(_saving ? 'Saving...' : (_creating ? 'Create canvas and save' : 'Add to selected canvas')),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _ThemePill extends StatelessWidget {
  final String themeKey;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ThemePill({required this.themeKey, required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = _themeColors(themeKey);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(colors: selected ? theme : [theme[0].withOpacity(.28), theme[1].withOpacity(.18)]),
          border: Border.all(color: selected ? Colors.transparent : theme[0].withOpacity(.45)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }

  List<Color> _themeColors(String key) {
    switch (key) {
      case 'rose':
        return const [Color(0xFFFF5B93), Color(0xFF8D63FF)];
      case 'mint':
        return const [Color(0xFF29D17D), Color(0xFF12C6FF)];
      case 'ember':
        return const [Color(0xFFFF8A3D), Color(0xFFFF5B93)];
      default:
        return const [Color(0xFF12C6FF), Color(0xFF8D63FF)];
    }
  }
}

extension on ResearchCanvasBlockDraft {
  ResearchCanvasBlockDraft copyWith({
    String? type,
    String? title,
    ValueGetter<String?>? question,
    String? content,
    String? sourceLabel,
    String? modelLabel,
    List<String>? tags,
    ValueGetter<String?>? mediaUrl,
    ValueGetter<String?>? thumbnailUrl,
    Map<String, dynamic>? extra,
  }) {
    return ResearchCanvasBlockDraft(
      type: type ?? this.type,
      title: title ?? this.title,
      question: question != null ? question() : this.question,
      content: content ?? this.content,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      modelLabel: modelLabel ?? this.modelLabel,
      tags: tags ?? this.tags,
      mediaUrl: mediaUrl != null ? mediaUrl() : this.mediaUrl,
      thumbnailUrl: thumbnailUrl != null ? thumbnailUrl() : this.thumbnailUrl,
      extra: extra ?? this.extra,
    );
  }
}

class _PrettyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _PrettyField({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: isLight ? Colors.black87 : Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isLight ? Colors.black38 : Colors.white38),
            filled: true,
            fillColor: isLight ? Colors.white : Colors.white.withOpacity(.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.transparent)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: isLight ? Colors.black12 : Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF4B8EFF), width: 1.2)),
          ),
        ),
      ],
    );
  }
}

class _ModePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModePill({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected ? const LinearGradient(colors: [Color(0xFF12C6FF), Color(0xFF8D63FF)]) : null,
          color: selected ? null : (isLight ? Colors.white : Colors.white.withOpacity(.05)),
          border: Border.all(color: selected ? Colors.transparent : (isLight ? Colors.black12 : Colors.white12)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : (isLight ? Colors.black87 : Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
