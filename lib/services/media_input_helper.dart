import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class PickedInputImage {
  final String dataUrl;
  final String? previewPath;

  const PickedInputImage({
    required this.dataUrl,
    required this.previewPath,
  });
}

class PickedInputAudio {
  final String dataUrl;
  final String? previewPath;
  final String label;

  const PickedInputAudio({
    required this.dataUrl,
    required this.previewPath,
    required this.label,
  });
}

class MediaInputHelper {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  Future<PickedInputImage?> pickFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return _fromImageBytes(bytes, p.extension(x.path), previewPath: x.path);
  }

  Future<PickedInputImage?> pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return _fromImageBytes(bytes, p.extension(x.path), previewPath: x.path);
  }

  Future<PickedInputImage?> pickFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return null;

    return _fromImageBytes(bytes, p.extension(f.name), previewPath: f.path);
  }

  Future<PickedInputAudio?> pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return null;

    return _fromAudioBytes(
      bytes,
      p.extension(f.name),
      previewPath: f.path,
      label: f.name,
    );
  }

  Future<PickedInputAudio?> recordVoiceNote({Duration maxDuration = const Duration(seconds: 20)}) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'gpmai_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    await Future.delayed(maxDuration);
    if (await _recorder.isRecording()) {
      final stopped = await _recorder.stop();
      if (stopped == null) return null;
      return await _audioFromPath(stopped, label: 'Voice note');
    }
    return null;
  }

  Future<void> startVoiceRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'gpmai_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
  }

  Future<PickedInputAudio?> stopVoiceRecording() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    return _audioFromPath(path, label: 'Voice note');
  }

  Future<void> cancelVoiceRecording() async {
    await _recorder.cancel();
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<PickedInputAudio> _audioFromPath(String path, {required String label}) async {
    final bytes = await File(path).readAsBytes();
    return _fromAudioBytes(bytes, p.extension(path), previewPath: path, label: label);
  }

  PickedInputImage _fromImageBytes(Uint8List bytes, String ext, {String? previewPath}) {
    final mime = _imageMimeFromExt(ext);
    final base64Data = base64Encode(bytes);
    final dataUrl = 'data:$mime;base64,$base64Data';
    return PickedInputImage(dataUrl: dataUrl, previewPath: previewPath);
  }

  PickedInputAudio _fromAudioBytes(Uint8List bytes, String ext, {String? previewPath, required String label}) {
    final mime = _audioMimeFromExt(ext);
    final base64Data = base64Encode(bytes);
    final dataUrl = 'data:$mime;base64,$base64Data';
    return PickedInputAudio(dataUrl: dataUrl, previewPath: previewPath, label: label);
  }

  String _imageMimeFromExt(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    switch (e) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'png':
      default:
        return 'image/png';
    }
  }

  String _audioMimeFromExt(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    switch (e) {
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
      default:
        return 'audio/mpeg';
    }
  }
}
