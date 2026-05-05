import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResearchCanvasBlockDraft {
  final String type;
  final String title;
  final String? question;
  final String content;
  final String sourceLabel;
  final String modelLabel;
  final List<String> tags;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final Map<String, dynamic> extra;

  const ResearchCanvasBlockDraft({
    required this.type,
    required this.title,
    this.question,
    required this.content,
    required this.sourceLabel,
    required this.modelLabel,
    this.tags = const <String>[],
    this.mediaUrl,
    this.thumbnailUrl,
    this.extra = const <String, dynamic>{},
  });

  ResearchCanvasBlock createBlock() {
    final now = DateTime.now();
    return ResearchCanvasBlock(
      id: 'block_${now.microsecondsSinceEpoch}',
      type: type,
      title: title,
      question: question,
      content: content,
      sourceLabel: sourceLabel,
      modelLabel: modelLabel,
      createdAt: now,
      tags: tags,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      extra: extra,
    );
  }
}

class ResearchCanvasBlock {
  final String id;
  final String type;
  final String title;
  final String? question;
  final String content;
  final String sourceLabel;
  final String modelLabel;
  final DateTime createdAt;
  final List<String> tags;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final Map<String, dynamic> extra;

  const ResearchCanvasBlock({
    required this.id,
    required this.type,
    required this.title,
    this.question,
    required this.content,
    required this.sourceLabel,
    required this.modelLabel,
    required this.createdAt,
    this.tags = const <String>[],
    this.mediaUrl,
    this.thumbnailUrl,
    this.extra = const <String, dynamic>{},
  });

  ResearchCanvasBlock copyWith({
    String? id,
    String? type,
    String? title,
    ValueGetter<String?>? question,
    String? content,
    String? sourceLabel,
    String? modelLabel,
    DateTime? createdAt,
    List<String>? tags,
    ValueGetter<String?>? mediaUrl,
    ValueGetter<String?>? thumbnailUrl,
    Map<String, dynamic>? extra,
  }) {
    return ResearchCanvasBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      question: question != null ? question() : this.question,
      content: content ?? this.content,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      modelLabel: modelLabel ?? this.modelLabel,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      mediaUrl: mediaUrl != null ? mediaUrl() : this.mediaUrl,
      thumbnailUrl: thumbnailUrl != null ? thumbnailUrl() : this.thumbnailUrl,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'title': title,
    'question': question,
    'content': content,
    'sourceLabel': sourceLabel,
    'modelLabel': modelLabel,
    'createdAt': createdAt.toIso8601String(),
    'tags': tags,
    'mediaUrl': mediaUrl,
    'thumbnailUrl': thumbnailUrl,
    'extra': extra,
  };

  factory ResearchCanvasBlock.fromJson(Map<String, dynamic> json) {
    return ResearchCanvasBlock(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString(),
      title: (json['title'] ?? 'Saved block').toString(),
      question: json['question']?.toString(),
      content: (json['content'] ?? '').toString(),
      sourceLabel: (json['sourceLabel'] ?? '').toString(),
      modelLabel: (json['modelLabel'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      tags: ((json['tags'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      mediaUrl: json['mediaUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      extra: Map<String, dynamic>.from(
        (json['extra'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }
}

class ResearchCanvas {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final String themeKey;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ResearchCanvasBlock> blocks;

  const ResearchCanvas({
    required this.id,
    required this.title,
    this.description = '',
    this.tags = const <String>[],
    this.themeKey = 'aurora',
    this.pinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.blocks = const <ResearchCanvasBlock>[],
  });

  ResearchCanvas copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? tags,
    String? themeKey,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ResearchCanvasBlock>? blocks,
  }) {
    return ResearchCanvas(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      themeKey: themeKey ?? this.themeKey,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      blocks: blocks ?? this.blocks,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'tags': tags,
    'themeKey': themeKey,
    'pinned': pinned,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'blocks': blocks.map((e) => e.toJson()).toList(growable: false),
  };

  factory ResearchCanvas.fromJson(Map<String, dynamic> json) {
    return ResearchCanvas(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled canvas').toString(),
      description: (json['description'] ?? '').toString(),
      tags: ((json['tags'] as List?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      themeKey: (json['themeKey'] ?? 'aurora').toString(),
      pinned: json['pinned'] == true,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      blocks: ((json['blocks'] as List?) ?? const <dynamic>[])
          .map(
            (e) => ResearchCanvasBlock.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ResearchCanvasStore {
  static const String _key = 'gpmai_research_canvases_v1';

  Future<List<ResearchCanvas>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return <ResearchCanvas>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final list = decoded
        .map(
          (e) => ResearchCanvas.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(growable: true);
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  Future<ResearchCanvas?> getById(String id) async {
    final all = await loadAll();
    for (final canvas in all) {
      if (canvas.id == id) return canvas;
    }
    return null;
  }

  Future<void> saveAll(List<ResearchCanvas> canvases) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(canvases.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Future<void> upsert(ResearchCanvas canvas) async {
    final all = await loadAll();
    final idx = all.indexWhere((e) => e.id == canvas.id);
    if (idx >= 0) {
      all[idx] = canvas;
    } else {
      all.add(canvas);
    }
    await saveAll(all);
  }

  Future<ResearchCanvas> createCanvas({
    required String title,
    String description = '',
    List<String> tags = const <String>[],
    String themeKey = 'aurora',
    List<ResearchCanvasBlock> blocks = const <ResearchCanvasBlock>[],
  }) async {
    final now = DateTime.now();
    final canvas = ResearchCanvas(
      id: 'canvas_${now.microsecondsSinceEpoch}',
      title: sanitizeTitleText(title),
      description: sanitizeBodyText(description),
      tags: normalizeTags(tags),
      themeKey: themeKey,
      createdAt: now,
      updatedAt: now,
      blocks: blocks,
    );
    await upsert(canvas);
    return canvas;
  }

  Future<void> renameCanvas(String id, String title) async {
    final canvas = await getById(id);
    if (canvas == null) return;
    await upsert(
      canvas.copyWith(
        title: sanitizeTitleText(title),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteCanvas(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    await saveAll(all);
  }

  Future<void> togglePinned(String id) async {
    final canvas = await getById(id);
    if (canvas == null) return;
    await upsert(
      canvas.copyWith(pinned: !canvas.pinned, updatedAt: DateTime.now()),
    );
  }

  Future<void> addBlock(String canvasId, ResearchCanvasBlock block) async {
    final canvas = await getById(canvasId);
    if (canvas == null) return;
    final updated = canvas.copyWith(
      blocks: <ResearchCanvasBlock>[
        block.copyWith(
          title: sanitizeTitleText(block.title),
          question:
              () =>
                  sanitizeBodyText(block.question).isEmpty
                      ? null
                      : sanitizeBodyText(block.question),
          content: sanitizeBodyText(block.content),
          sourceLabel: sanitizeTitleText(block.sourceLabel),
          modelLabel: sanitizeTitleText(block.modelLabel),
          tags: normalizeTags(block.tags),
          mediaUrl: () => sanitizeBodyText(block.mediaUrl),
          thumbnailUrl: () => sanitizeBodyText(block.thumbnailUrl),
          extra: Map<String, dynamic>.from(block.extra),
        ),
        ...canvas.blocks,
      ],
      tags: normalizeTags(<String>[...canvas.tags, ...block.tags]),
      updatedAt: DateTime.now(),
    );
    await upsert(updated);
  }

  Future<void> addDraftToCanvas(
    String canvasId,
    ResearchCanvasBlockDraft draft,
  ) async {
    await addBlock(canvasId, draft.createBlock());
  }

  Future<void> deleteBlock(String canvasId, String blockId) async {
    final canvas = await getById(canvasId);
    if (canvas == null) return;
    await upsert(
      canvas.copyWith(
        blocks: canvas.blocks
            .where((e) => e.id != blockId)
            .toList(growable: false),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> updateBlock(String canvasId, ResearchCanvasBlock block) async {
    final canvas = await getById(canvasId);
    if (canvas == null) return;
    final next = canvas.blocks
        .map((e) => e.id == block.id ? block : e)
        .toList(growable: false);
    await upsert(
      canvas.copyWith(
        blocks: next
            .map(
              (e) => e.copyWith(
                title: sanitizeTitleText(e.title),
                question:
                    () =>
                        sanitizeBodyText(e.question).isEmpty
                            ? null
                            : sanitizeBodyText(e.question),
                content: sanitizeBodyText(e.content),
                sourceLabel: sanitizeTitleText(e.sourceLabel),
                modelLabel: sanitizeTitleText(e.modelLabel),
                tags: normalizeTags(e.tags),
                mediaUrl: () => sanitizeBodyText(e.mediaUrl),
                thumbnailUrl: () => sanitizeBodyText(e.thumbnailUrl),
                extra: Map<String, dynamic>.from(e.extra),
              ),
            )
            .toList(growable: false),
        tags: normalizeTags(<String>[
          ...canvas.tags,
          ...next.expand((e) => e.tags),
        ]),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<List<ResearchCanvasBlock>> findByTag(String tag) async {
    final needle = normalizeTag(tag);
    if (needle.isEmpty) return const <ResearchCanvasBlock>[];
    final all = await loadAll();
    return all
        .expand(
          (canvas) => canvas.blocks.where(
            (b) => b.tags.map(normalizeTag).contains(needle),
          ),
        )
        .toList(growable: false);
  }

  static List<String> normalizeTags(Iterable<String> tags) {
    final out = <String>{};
    for (final raw in tags) {
      final normalized = normalizeTag(raw);
      if (normalized.isNotEmpty) out.add(normalized);
    }
    return out.toList(growable: false);
  }

  static String normalizeTag(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), '-').toLowerCase();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('#') ? trimmed : '#$trimmed';
  }

  static String sanitizeBodyText(String? raw) {
    var text = (raw ?? '').replaceAll('\r\n', '\n');
    if (text.trim().isEmpty) return '';
    text = text.replaceAll(
      RegExp(r'<<META>>.*?<<ENDMETA>>', dotAll: true),
      ' ',
    );
    text = text.replaceAll(RegExp(r'^<<META>>.*?\}', dotAll: true), ' ');
    const replacements = <String, String>{
      'â€¢': '•',
      'â€”': '—',
      'â€“': '–',
      'â€˜': '‘',
      'â€™': '’',
      'â€œ': '“',
      'â€\x9d': '”',
      'â€¦': '…',
      'Â ': ' ',
      'Â': '',
      'Ã—': '×',
      'âœ¨': '✨',
      'âœ”': '✔',
      'âœ…': '✅',
      'â€ ': '†',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    text = text.replaceAll(
      RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'),
      '',
    );
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static String sanitizeTitleText(String? raw) {
    final cleaned = sanitizeBodyText(raw).replaceAll('\n', ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool looksLikeLocalPath(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return false;
    return value.startsWith('/data/') ||
        value.startsWith('/storage/') ||
        value.startsWith('file://') ||
        value.contains('app_flutter/') ||
        value.contains('gpmai_media/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(value);
  }

  static String localPathLabel(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    final normalized = value.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return sanitizeTitleText(parts.isEmpty ? value : parts.last);
  }

  static List<String> suggestTags({
    String? title,
    String? content,
    String? sourceLabel,
    String? type,
  }) {
    final source =
        sanitizeBodyText(
          [title ?? '', content ?? '', sourceLabel ?? '', type ?? ''].join(' '),
        ).toLowerCase();
    final words = RegExp(r'[a-z0-9][a-z0-9\-]{2,}')
        .allMatches(source)
        .map((m) => m.group(0)!)
        .where(
          (w) =>
              !const {
                'with',
                'this',
                'that',
                'from',
                'into',
                'your',
                'have',
                'about',
                'after',
                'before',
                'which',
                'would',
                'could',
                'there',
                'their',
                'saved',
                'canvas',
                'block',
                'title',
                'write',
                'note',
                'section',
                'result',
                'answer',
                'video',
                'audio',
                'image',
              }.contains(w),
        )
        .toList(growable: false);
    final seen = <String>{};
    final out = <String>[];
    for (final word in words) {
      final tag = normalizeTag(word);
      if (tag.length > 2 && seen.add(tag)) {
        out.add(tag);
      }
      if (out.length >= 5) break;
    }
    return out;
  }

  static List<String> parseTags(String raw) {
    return normalizeTags(
      raw
          .split(RegExp(r'[\s,]+'))
          .where((e) => e.trim().isNotEmpty)
          .map((e) => e.trim()),
    );
  }
}
