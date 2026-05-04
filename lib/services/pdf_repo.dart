import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SavedPdf {
  final String id;
  final String name;
  final String path;      // file path to the PDF
  final int pages;
  final String lang;      // e.g. 'English'
  final String summary;   // 1 paragraph
  final List<String> keyPoints; // bullets
  final DateTime createdAt;
  final String notesMarkdown; // free-form user notes

  SavedPdf({
    required this.id,
    required this.name,
    required this.path,
    required this.pages,
    required this.lang,
    required this.summary,
    required this.keyPoints,
    required this.createdAt,
    required this.notesMarkdown,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'path': path, 'pages': pages, 'lang': lang,
    'summary': summary, 'keyPoints': keyPoints, 'createdAt': createdAt.millisecondsSinceEpoch,
    'notesMarkdown': notesMarkdown,
  };

  factory SavedPdf.fromJson(Map<String, dynamic> m) => SavedPdf(
    id: m['id'], name: m['name'], path: m['path'], pages: m['pages'] ?? 0,
    lang: m['lang'] ?? 'English', summary: m['summary'] ?? '',
    keyPoints: (m['keyPoints'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
    notesMarkdown: m['notesMarkdown'] ?? '',
  );
}

class PdfRepo {
  static final PdfRepo I = PdfRepo._();
  PdfRepo._();

  List<SavedPdf> _items = [];
  File? _storeFile;

  Future<void> _ensureLoaded() async {
    if (_storeFile != null) return;
    final dir = await getApplicationDocumentsDirectory();
    _storeFile = File(p.join(dir.path, 'pdf_repo.json'));
    if (await _storeFile!.exists()) {
      try {
        final txt = await _storeFile!.readAsString();
        final list = (jsonDecode(txt) as List).cast<Map<String, dynamic>>();
        _items = list.map(SavedPdf.fromJson).toList();
      } catch (_) {
        _items = [];
      }
    }
  }

  Future<List<SavedPdf>> all() async {
    await _ensureLoaded();
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(_items);
  }

  Future<void> _save() async {
    try {
      await _storeFile!.writeAsString(jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<SavedPdf?> getById(String id) async {
    await _ensureLoaded();
    try { return _items.firstWhere((e) => e.id == id); } catch (_) { return null; }
  }

  Future<SavedPdf> addFromBytes({
    required String name,
    required Uint8List bytes,
    required int pages,
    required String lang,
    required String summary,
    required List<String> keyPoints,
  }) async {
    await _ensureLoaded();
    final dir = await getApplicationDocumentsDirectory();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final path = p.join(dir.path, 'pdf_$id.pdf');
    await File(path).writeAsBytes(bytes);
    final item = SavedPdf(
      id: id, name: name, path: path, pages: pages, lang: lang,
      summary: summary, keyPoints: keyPoints, createdAt: DateTime.now(), notesMarkdown: '',
    );
    _items.add(item);
    await _save();
    return item;
  }

  Future<void> updateNotes(String id, String md) async {
    await _ensureLoaded();
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) {
      _items[i] = SavedPdf(
        id: _items[i].id,
        name: _items[i].name,
        path: _items[i].path,
        pages: _items[i].pages,
        lang: _items[i].lang,
        summary: _items[i].summary,
        keyPoints: _items[i].keyPoints,
        createdAt: _items[i].createdAt,
        notesMarkdown: md,
      );
      await _save();
    }
  }
}
