import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_result.dart';



class ActiveGenerationSession {
  final String category;
  final String modelId;
  final String modelName;
  final String prompt;
  final String predictionId;
  final DateTime startedAt;

  const ActiveGenerationSession({
    required this.category,
    required this.modelId,
    required this.modelName,
    required this.prompt,
    required this.predictionId,
    required this.startedAt,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'modelId': modelId,
        'modelName': modelName,
        'prompt': prompt,
        'predictionId': predictionId,
        'startedAt': startedAt.toIso8601String(),
      };

  factory ActiveGenerationSession.fromJson(Map<String, dynamic> json) {
    return ActiveGenerationSession(
      category: (json['category'] ?? '').toString(),
      modelId: (json['modelId'] ?? '').toString(),
      modelName: (json['modelName'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      predictionId: (json['predictionId'] ?? '').toString(),
      startedAt: DateTime.tryParse((json['startedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class MediaHistoryStore {
  static const String _key = 'gpmai_media_history_v1';
  static const String _activeKeyPrefix = 'gpmai_active_generation_';



  Future<void> saveActiveGeneration(ActiveGenerationSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_activeKeyPrefix${session.category.toLowerCase()}',
      jsonEncode(session.toJson()),
    );
  }

  Future<ActiveGenerationSession?> loadActiveGeneration(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_activeKeyPrefix${category.toLowerCase()}');
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ActiveGenerationSession.fromJson(decoded);
      }
      if (decoded is Map) {
        return ActiveGenerationSession.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearActiveGeneration(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_activeKeyPrefix${category.toLowerCase()}');
  }

  Future<List<GeneratedMediaItem>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];

    return raw
        .map((e) {
          try {
            final decoded = jsonDecode(e);
            if (decoded is Map<String, dynamic>) {
              return GeneratedMediaItem.fromJson(decoded);
            }
            if (decoded is Map) {
              return GeneratedMediaItem.fromJson(decoded.cast<String, dynamic>());
            }
          } catch (_) {}
          return null;
        })
        .whereType<GeneratedMediaItem>()
        .toList(growable: true);
  }

  Future<List<GeneratedMediaItem>> loadByCategory(String category) async {
    final all = await loadAll();
    return all
        .where((e) => _matchesCategory(e, category))
        .toList(growable: true);
  }

  Future<List<GeneratedMediaItem>> loadByCategoryAndModel(
    String category,
    String modelId,
  ) async {
    final all = await loadAll();
    final filtered = all.where((item) {
      return _matchesCategory(item, category) && _matchesModel(item.modelId, modelId);
    }).toList(growable: true);

    filtered.sort(_sortPinnedNewestFirst);
    return filtered;
  }

  Future<void> saveAll(List<GeneratedMediaItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = _enforcePerModelLimit(_dedupe(items));
    final raw = cleaned.map((e) => jsonEncode(e.toJson())).toList(growable: false);
    await prefs.setStringList(_key, raw);
  }

  Future<void> prependItems(List<GeneratedMediaItem> items) async {
    final all = await loadAll();
    final next = <GeneratedMediaItem>[...items, ...all];
    await saveAll(next);
  }

  Future<void> upsertItem(GeneratedMediaItem nextItem) async {
    final all = await loadAll();
    final next = all.map((item) {
      if (_sameItem(item, nextItem)) return nextItem;
      return item;
    }).toList(growable: true);

    final found = next.any((item) => _sameItem(item, nextItem));
    if (!found) {
      next.insert(0, nextItem);
    }

    await saveAll(_dedupe(next));
  }

  Future<void> togglePinned(GeneratedMediaItem target) async {
    final metadata = Map<String, dynamic>.from(target.metadata);
    metadata['pinned'] = !(metadata['pinned'] == true);
    await upsertItem(target.copyWith(metadata: metadata));
  }


  Future<void> renameItem(GeneratedMediaItem target, String newTitle) async {
    final title = newTitle.trim();
    if (title.isEmpty) return;
    final metadata = Map<String, dynamic>.from(target.metadata);
    metadata['customTitle'] = title;
    await upsertItem(target.copyWith(metadata: metadata));
  }

  Future<void> deleteItem(GeneratedMediaItem target) async {
    final all = await loadAll();
    final next = all.where((item) => !_sameItem(item, target)).toList(growable: false);
    await saveAll(next);
  }

  Future<void> clearByCategoryAndModel(String category, String modelId) async {
    final all = await loadAll();
    final next = all.where((item) {
      return !(_matchesCategory(item, category) && _matchesModel(item.modelId, modelId));
    }).toList(growable: false);

    await saveAll(next);
  }


  bool _matchesCategory(GeneratedMediaItem item, String category) {
    final wanted = category.trim().toLowerCase();
    final raw = item.category.trim().toLowerCase();
    if (raw == wanted) return true;
    return item.mediaType.key.toLowerCase() == wanted;
  }

  bool _matchesModel(String a, String b) {
    return _canonicalModelId(a) == _canonicalModelId(b);
  }

  String _canonicalModelId(String modelId) {
    return modelId.trim().toLowerCase();
  }

  List<GeneratedMediaItem> _enforcePerModelLimit(List<GeneratedMediaItem> items) {
    const maxPerModel = 15;
    final grouped = <String, List<GeneratedMediaItem>>{};

    for (final item in items) {
      final key = '${item.mediaType.key}|${_canonicalModelId(item.modelId)}';
      grouped.putIfAbsent(key, () => <GeneratedMediaItem>[]).add(item);
    }

    final keptKeys = <String>{};
    final out = <GeneratedMediaItem>[];

    for (final entry in grouped.entries) {
      final group = List<GeneratedMediaItem>.from(entry.value)
        ..sort(_sortPinnedNewestFirst);

      final pinned = <GeneratedMediaItem>[];
      final unpinned = <GeneratedMediaItem>[];
      for (final item in group) {
        if (item.metadata['pinned'] == true) {
          pinned.add(item);
        } else {
          unpinned.add(item);
        }
      }

      final keep = <GeneratedMediaItem>[...pinned];
      final room = maxPerModel - keep.length;
      if (room > 0) {
        keep.addAll(unpinned.take(room));
      }
      for (final item in keep) {
        keptKeys.add(_idFor(item));
      }
    }

    for (final item in items) {
      if (keptKeys.remove(_idFor(item))) {
        out.add(item);
      }
    }
    return out;
  }

  int _sortPinnedNewestFirst(GeneratedMediaItem a, GeneratedMediaItem b) {
    final ap = (a.metadata['pinned'] == true) ? 1 : 0;
    final bp = (b.metadata['pinned'] == true) ? 1 : 0;
    if (ap != bp) return bp.compareTo(ap);
    return b.createdAt.compareTo(a.createdAt);
  }

  List<GeneratedMediaItem> _dedupe(List<GeneratedMediaItem> items) {
    final seen = <String>{};
    final out = <GeneratedMediaItem>[];

    for (final item in items) {
      final key = _idFor(item);
      if (seen.add(key)) {
        out.add(item);
      }
    }
    return out;
  }

  bool _sameItem(GeneratedMediaItem a, GeneratedMediaItem b) {
    return _idFor(a) == _idFor(b);
  }

  String _idFor(GeneratedMediaItem item) {
    final prediction = item.predictionId?.trim() ?? '';
    if (prediction.isNotEmpty) return 'pred:$prediction';
    return 'url:${item.previewUrl}|model:${item.modelId}|ts:${item.createdAt.toIso8601String()}';
  }
}
