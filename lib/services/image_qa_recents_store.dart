// lib/services/image_qa_recents_store.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class ImageQAMessage {
  final String role;        // "user" | "ai" | "system"
  final String text;
  final DateTime at;

  ImageQAMessage({required this.role, required this.text, DateTime? at})
      : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'at': at.toIso8601String(),
      };

  static ImageQAMessage fromJson(Map<String, dynamic> j) => ImageQAMessage(
        role: (j['role'] as String?)?.trim().isNotEmpty == true ? j['role'] as String : 'system',
        text: (j['text'] as String?) ?? '',
        at: DateTime.tryParse((j['at'] ?? '') as String) ?? DateTime.now(),
      );
}

class ImageQARecentItem {
  final String id;
  String title;
  bool pinned;
  final DateTime createdAt;
  final String imagePath; // absolute file path on device
  final String? prompt;   // optional first prompt/idea used

  ImageQARecentItem({
    required this.id,
    required this.title,
    required this.pinned,
    required this.createdAt,
    required this.imagePath,
    this.prompt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
        'imagePath': imagePath,
        'prompt': prompt,
      };

  static ImageQARecentItem fromJson(Map<String, dynamic> j) => ImageQARecentItem(
        id: j['id'] as String,
        title: (j['title'] as String?)?.trim().isNotEmpty == true ? j['title'] as String : 'Untitled',
        pinned: j['pinned'] == true,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String) ?? DateTime.now(),
        imagePath: j['imagePath'] as String,
        prompt: (j['prompt'] as String?)?.trim().isNotEmpty == true ? j['prompt'] as String : null,
      );
}

class ImageQARecentsStore {
  ImageQARecentsStore._();

  /* ---------- paths ---------- */

  static Future<Directory> _baseDir() async {
    final app = await getApplicationDocumentsDirectory();
    final dir = Directory('${app.path}/image_qa_recents');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _indexFile() async {
    final dir = await _baseDir();
    return File('${dir.path}/index.json');
  }

  static Future<File> _imageFile(String id) async {
    final dir = await _baseDir();
    return File('${dir.path}/$id.png');
  }

  static Future<File> _chatFile(String id) async {
    final dir = await _baseDir();
    return File('${dir.path}/$id.chat.json');
  }

  /* ---------- load/save index ---------- */

  static Future<List<ImageQARecentItem>> _loadIndex() async {
    try {
      final f = await _indexFile();
      if (!await f.exists()) return <ImageQARecentItem>[];
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final arr = (j['items'] as List?) ?? const [];
      return arr
          .whereType<Map<String, dynamic>>()
          .map(ImageQARecentItem.fromJson)
          .toList();
    } catch (_) {
      return <ImageQARecentItem>[];
    }
  }

  static Future<void> _saveIndex(List<ImageQARecentItem> items) async {
    final f = await _indexFile();
    final j = {'items': items.map((e) => e.toJson()).toList()};
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(j), flush: true);
  }

  /* ---------- public API (recents) ---------- */

  /// Add one recent (stores the PNG bytes and registers an index entry).
  static Future<ImageQARecentItem> add(Uint8List imageBytes, {String? prompt}) async {
    final id = _newId();
    final imgFile = await _imageFile(id);
    await imgFile.writeAsBytes(imageBytes, flush: true);

    final items = await _loadIndex();
    final item = ImageQARecentItem(
      id: id,
      title: (prompt?.trim().isNotEmpty ?? false) ? prompt!.trim() : 'Untitled',
      pinned: false,
      createdAt: DateTime.now(),
      imagePath: imgFile.path,
      prompt: prompt?.trim().isNotEmpty == true ? prompt!.trim() : null,
    );
    items.insert(0, item);
    await _saveIndex(items);

    // bootstrap empty chat file
    await _saveChat(id, <ImageQAMessage>[]);

    return item;
  }

  static Future<List<ImageQARecentItem>> list() async {
    final items = await _loadIndex();
    // Pinned first, then newest first
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
  }

  static Future<void> deleteAll() async {
    final items = await _loadIndex();
    for (final it in items) {
      try {
        final f = File(it.imagePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      try {
        final cf = await _chatFile(it.id);
        if (await cf.exists()) await cf.delete();
      } catch (_) {}
    }
    await _saveIndex(<ImageQARecentItem>[]);
  }

  static Future<void> removeMany(List<String> ids) async {
    final items = await _loadIndex();
    final keep = <ImageQARecentItem>[];
    for (final it in items) {
      if (ids.contains(it.id)) {
        try {
          final f = File(it.imagePath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
        try {
          final cf = await _chatFile(it.id);
          if (await cf.exists()) await cf.delete();
        } catch (_) {}
      } else {
        keep.add(it);
      }
    }
    await _saveIndex(keep);
  }

  static Future<void> togglePinMany(List<String> ids, {required bool pinned}) async {
    final items = await _loadIndex();
    for (final it in items) {
      if (ids.contains(it.id)) it.pinned = pinned;
    }
    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    await _saveIndex(items);
  }

  static Future<void> rename(String id, String newTitle) async {
    final items = await _loadIndex();
    for (final it in items) {
      if (it.id == id) {
        it.title = newTitle.trim().isEmpty ? 'Untitled' : newTitle.trim();
        break;
      }
    }
    await _saveIndex(items);
  }

  /// Read stored PNG back (useful if you show a preview).
  static Future<Uint8List?> readImage(String id) async {
    final f = await _imageFile(id);
    if (await f.exists()) return f.readAsBytes();
    return null;
  }

  /* ---------- per-item chat API ---------- */

  static Future<List<ImageQAMessage>> loadChat(String id) async {
    try {
      final f = await _chatFile(id);
      if (!await f.exists()) return <ImageQAMessage>[];
      final j = jsonDecode(await f.readAsString());
      final arr = (j['messages'] as List?) ?? const [];
      return arr
          .whereType<Map<String, dynamic>>()
          .map(ImageQAMessage.fromJson)
          .toList();
    } catch (_) {
      return <ImageQAMessage>[];
    }
  }

  static Future<void> appendChat(String id, ImageQAMessage msg) async {
    final cur = await loadChat(id);
    cur.add(msg);
    await _saveChat(id, cur);
  }

  static Future<void> replaceChat(String id, List<ImageQAMessage> msgs) async {
    await _saveChat(id, msgs);
  }

  static Future<void> clearChat(String id) async {
    await _saveChat(id, <ImageQAMessage>[]);
  }

  static Future<void> _saveChat(String id, List<ImageQAMessage> msgs) async {
    final f = await _chatFile(id);
    final payload = {'messages': msgs.map((e) => e.toJson()).toList()};
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
  }

  /* ---------- helpers ---------- */

  static String _newId() {
    final r = Random();
    final t = DateTime.now().microsecondsSinceEpoch;
    final salt = r.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'r${t.toRadixString(16)}$salt';
    // Example: r18b9d3a8e34f1a2b
  }
}
