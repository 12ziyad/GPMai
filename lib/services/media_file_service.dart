import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/media_result.dart';

class MediaFileService {
  static String displayTitle(GeneratedMediaItem item) {
    final custom = item.metadata['customTitle']?.toString().trim() ?? '';
    if (custom.isNotEmpty) return custom;
    return item.modelName.trim().isNotEmpty ? item.modelName : 'GPMai Media';
  }

  static Future<File> downloadToAppFile(GeneratedMediaItem item) async {
    final localPath = item.localFilePath;
    if (localPath != null && localPath.trim().isNotEmpty) {
      final local = File(localPath);
      if (await local.exists()) return local;
    }

    final uri = Uri.parse(item.remoteUrl);
    final res = await http.get(uri);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Download failed (${res.statusCode})');
    }

    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'gpmai_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final ext = _guessExtension(item, uri, res.bodyBytes);
    final safeTitle = _safeFileName(displayTitle(item));
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(mediaDir.path, '${safeTitle}_$ts$ext'));

    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file;
  }

  static Future<String> downloadAndGetPath(GeneratedMediaItem item) async {
    final file = await downloadToAppFile(item);
    final ext = p.extension(file.path);
    final suggested = '${_safeFileName(displayTitle(item))}$ext';

    try {
      final bytes = await file.readAsBytes();
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save media',
        fileName: suggested,
        bytes: bytes,
      );
      if (savedPath != null && savedPath.trim().isNotEmpty) {
        return savedPath;
      }
    } catch (_) {
      // Fallback to local cached file below.
    }

    return file.path;
  }


  static Future<GeneratedMediaItem> cacheItemLocally(GeneratedMediaItem item) async {
    try {
      final file = await downloadToAppFile(item);
      final metadata = Map<String, dynamic>.from(item.metadata);
      metadata['localFilePath'] = file.path;
      return item.copyWith(metadata: metadata);
    } catch (_) {
      return item;
    }
  }

  static Future<List<GeneratedMediaItem>> cacheItemsLocally(List<GeneratedMediaItem> items) async {
    final out = <GeneratedMediaItem>[];
    for (final item in items) {
      out.add(await cacheItemLocally(item));
    }
    return out;
  }

  static Future<void> shareItem(GeneratedMediaItem item) async {
    final file = await downloadToAppFile(item);
    final xFile = XFile(file.path);
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: displayTitle(item),
      ),
    );
  }

  static String _safeFileName(String input) {
    final s = input.trim().isEmpty ? 'gpmai_media' : input.trim();
    return s
        .replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  static String _guessExtension(
    GeneratedMediaItem item,
    Uri uri,
    Uint8List bytes,
  ) {
    final lowerPath = uri.path.toLowerCase();

    if (lowerPath.endsWith('.png')) return '.png';
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) return '.jpg';
    if (lowerPath.endsWith('.webp')) return '.webp';
    if (lowerPath.endsWith('.gif')) return '.gif';
    if (lowerPath.endsWith('.mp3')) return '.mp3';
    if (lowerPath.endsWith('.wav')) return '.wav';
    if (lowerPath.endsWith('.m4a')) return '.m4a';
    if (lowerPath.endsWith('.aac')) return '.aac';
    if (lowerPath.endsWith('.ogg')) return '.ogg';
    if (lowerPath.endsWith('.flac')) return '.flac';
    if (lowerPath.endsWith('.mp4')) return '.mp4';
    if (lowerPath.endsWith('.mov')) return '.mov';
    if (lowerPath.endsWith('.webm')) return '.webm';
    if (lowerPath.endsWith('.mkv')) return '.mkv';

    if (item.isAudio) return '.mp3';
    if (item.isVideo) return '.mp4';
    if (item.isImage) return '.png';

    return '.bin';
  }
}
