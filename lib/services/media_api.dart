import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../models/media_result.dart';

class MediaGenerationRequest {
  final String modelId;
  final String category;
  final String prompt;
  final Map<String, dynamic> input;
  final List<String> inputUrls;

  const MediaGenerationRequest({
    required this.modelId,
    required this.category,
    required this.prompt,
    this.input = const {},
    this.inputUrls = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'modelId': modelId,
      'category': category,
      'prompt': prompt,
      'input': input,
      'inputUrls': inputUrls,
    };
  }
}

class MediaGenerationResult {
  final bool ok;
  final String provider;
  final String category;
  final String model;
  final String predictionId;
  final String status;
  final bool processing;
  final dynamic output;
  final Map<String, dynamic>? metrics;
  final int pointsCost;
  final int? pointsBalanceAfter;
  final String? error;
  final String? pollUrl;

  // compatibility fields
  final double usdCost;
  final String? pricingSource;
  final String? pricingVersion;

  const MediaGenerationResult({
    required this.ok,
    required this.provider,
    required this.category,
    required this.model,
    required this.predictionId,
    required this.status,
    required this.processing,
    required this.output,
    required this.metrics,
    required this.pointsCost,
    required this.pointsBalanceAfter,
    required this.error,
    required this.pollUrl,
    required this.usdCost,
    required this.pricingSource,
    required this.pricingVersion,
  });

  factory MediaGenerationResult.fromJson(Map<String, dynamic> json) {
    final gpmai = (json['_gpmai'] is Map)
        ? Map<String, dynamic>.from(json['_gpmai'])
        : <String, dynamic>{};
    final walletAfter = (gpmai['walletAfter'] is Map)
        ? Map<String, dynamic>.from(gpmai['walletAfter'])
        : <String, dynamic>{};

    return MediaGenerationResult(
      ok: json['ok'] == true,
      provider: (json['provider'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      predictionId: (json['predictionId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      processing: json['processing'] == true,
      output: json['output'],
      metrics: json['metrics'] is Map ? Map<String, dynamic>.from(json['metrics']) : null,
      pointsCost: (gpmai['pointsCost'] is num) ? (gpmai['pointsCost'] as num).round() : 0,
      pointsBalanceAfter: (walletAfter['pointsBalance'] is num)
          ? (walletAfter['pointsBalance'] as num).round()
          : null,
      error: json['error']?.toString(),
      pollUrl: json['pollUrl']?.toString(),
      usdCost: (gpmai['usdCost'] is num) ? (gpmai['usdCost'] as num).toDouble() : 0.0,
      pricingSource: gpmai['pricingSource']?.toString(),
      pricingVersion: gpmai['pricingVersion']?.toString(),
    );
  }

  // old compatibility getter
  String get modelId => model;

  List<String> normalizedUrls() {
    final out = <String>[];

    void addOne(dynamic value) {
      if (value == null) return;
      final s = value.toString().trim();
      if (s.isEmpty) return;
      final lower = s.toLowerCase();
      final looksLikeUrl = s.startsWith('http://') ||
          s.startsWith('https://') ||
          s.startsWith('data:') ||
          lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mkv') ||
          lower.endsWith('.mp3') ||
          lower.endsWith('.wav') ||
          lower.endsWith('.m4a') ||
          lower.endsWith('.aac') ||
          lower.endsWith('.ogg') ||
          lower.endsWith('.flac');
      if (!looksLikeUrl) return;
      out.add(s);
    }

    void visit(dynamic node) {
      if (node == null) return;
      if (node is String) {
        addOne(node);
        return;
      }
      if (node is List) {
        for (final item in node) {
          visit(item);
        }
        return;
      }
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);
        const priorityKeys = [
          'url',
          'uri',
          'output',
          'outputs',
          'urls',
          'image',
          'images',
          'image_url',
          'image_urls',
          'video',
          'videos',
          'video_url',
          'video_urls',
          'audio',
          'audios',
          'audio_url',
          'audio_urls',
          'file',
          'files',
          'thumbnail',
          'thumbnails',
          'artifacts',
          'data',
        ];
        for (final key in priorityKeys) {
          if (map.containsKey(key)) {
            visit(map[key]);
          }
        }
        for (final entry in map.entries) {
          if (!priorityKeys.contains(entry.key)) {
            visit(entry.value);
          }
        }
      }
    }

    visit(output);
    return out.toSet().toList(growable: false);
  }

  // old compatibility getter
  List<String> get outputUrls => normalizedUrls();

  List<GeneratedMediaItem> toGeneratedItems({
    required String prompt,
    required String modelName,
    required DateTime createdAt,
  }) {
    final urls = normalizedUrls();
    if (urls.isEmpty) return const [];

    final mediaType = _typeFromCategory(category);

    return urls
        .map(
          (url) => GeneratedMediaItem.fromOutput(
            url: url,
            modelId: model,
            modelName: modelName,
            prompt: prompt,
            pointsCost: pointsCost,
            createdAt: createdAt,
            category: category,
            provider: provider,
            predictionId: predictionId.isEmpty ? null : predictionId,
            allUrls: urls,
            metadata: metrics ?? const <String, dynamic>{},
          ).copyWith(mediaType: mediaType),
        )
        .toList(growable: false);
  }

  static GeneratedMediaType _typeFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'image':
        return GeneratedMediaType.image;
      case 'video':
        return GeneratedMediaType.video;
      case 'audio':
        return GeneratedMediaType.audio;
      default:
        return GeneratedMediaType.unknown;
    }
  }
}

class MediaApi {
  static const String _baseUrl = String.fromEnvironment(
    'GPMAI_WORKER_BASE_URL',
    defaultValue: 'https://gpmai-api.gpmai.workers.dev',
  );


  static Future<String?> _getFirebaseIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken();
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getFirebaseIdToken();

    return {
      'Content-Type': 'application/json',      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<MediaGenerationResult> startGeneration(
    MediaGenerationRequest request,
  ) async {
    final uri = Uri.parse('$_baseUrl/media/generate');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );

    final json = _decodeJson(res.body);
    final first = MediaGenerationResult.fromJson(json);

    if (res.statusCode >= 400 || !first.ok) {
      throw Exception((first.error != null && first.error!.trim().isNotEmpty) ? first.error! : 'Media generation failed (HTTP ${res.statusCode}): ${res.body}');
    }

    return first;
  }

  static Future<MediaGenerationResult> generate(
    MediaGenerationRequest request, {
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 4),
  }) async {
    final first = await startGeneration(request);

    if (!first.processing) {
      return first;
    }

    if (first.predictionId.isEmpty) {
      throw Exception('Prediction started but predictionId is missing');
    }

    return await waitForCompletion(
      predictionId: first.predictionId,
      category: request.category,
      model: request.modelId,
      pollInterval: pollInterval,
      timeout: timeout,
    );
  }

  static Future<List<GeneratedMediaItem>> generateItems({
    required String modelId,
    required String modelName,
    required String category,
    required String prompt,
    Map<String, dynamic> input = const {},
    List<String> inputUrls = const [],
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 4),
  }) async {
    final result = await generate(
      MediaGenerationRequest(
        modelId: modelId,
        category: category,
        prompt: prompt,
        input: input,
        inputUrls: inputUrls,
      ),
      pollInterval: pollInterval,
      timeout: timeout,
    );

    return result.toGeneratedItems(
      prompt: prompt,
      modelName: modelName,
      createdAt: DateTime.now(),
    );
  }

  static Future<MediaGenerationResult> waitForCompletion({
    required String predictionId,
    required String category,
    required String model,
    Duration pollInterval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 4),
  }) async {
    final started = DateTime.now();

    while (true) {
      if (DateTime.now().difference(started) > timeout) {
        throw Exception('Generation timed out. Please try again.');
      }

      await Future.delayed(pollInterval);

      final status = await getStatus(
        predictionId: predictionId,
        category: category,
        model: model,
      );

      if (status.processing) {
        continue;
      }

      if (!status.ok) {
        throw Exception(status.error ?? 'Generation failed');
      }

      return status;
    }
  }

  static Future<MediaGenerationResult> getStatus({
    required String predictionId,
    required String category,
    required String model,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/media/status?predictionId=${Uri.encodeQueryComponent(predictionId)}&category=${Uri.encodeQueryComponent(category)}&model=${Uri.encodeQueryComponent(model)}',
    );

    final res = await http.get(
      uri,
      headers: await _headers(),
    );

    final json = _decodeJson(res.body);
    final result = MediaGenerationResult.fromJson(json);

    if (res.statusCode >= 400 && !result.processing) {
      throw Exception((result.error != null && result.error!.trim().isNotEmpty) ? result.error! : 'Failed to fetch media status (HTTP ${res.statusCode}): ${res.body}');
    }

    return result;
  }

  static Map<String, dynamic> _decodeJson(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }
}










