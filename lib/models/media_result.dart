enum GeneratedMediaType {
  image,
  video,
  audio,
  unknown;

  String get key {
    switch (this) {
      case GeneratedMediaType.image:
        return 'image';
      case GeneratedMediaType.video:
        return 'video';
      case GeneratedMediaType.audio:
        return 'audio';
      case GeneratedMediaType.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case GeneratedMediaType.image:
        return 'Image';
      case GeneratedMediaType.video:
        return 'Video';
      case GeneratedMediaType.audio:
        return 'Audio';
      case GeneratedMediaType.unknown:
        return 'Unknown';
    }
  }

  bool get isImage => this == GeneratedMediaType.image;
  bool get isVideo => this == GeneratedMediaType.video;
  bool get isAudio => this == GeneratedMediaType.audio;

  static GeneratedMediaType fromCategory(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    switch (v) {
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

  static GeneratedMediaType fromUrl(String? raw) {
    final url = (raw ?? '').trim().toLowerCase();
    if (url.isEmpty) return GeneratedMediaType.unknown;

    if (url.endsWith('.png') ||
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.webp') ||
        url.endsWith('.gif')) {
      return GeneratedMediaType.image;
    }

    if (url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.webm') ||
        url.endsWith('.mkv')) {
      return GeneratedMediaType.video;
    }

    if (url.endsWith('.mp3') ||
        url.endsWith('.wav') ||
        url.endsWith('.m4a') ||
        url.endsWith('.aac') ||
        url.endsWith('.ogg') ||
        url.endsWith('.flac')) {
      return GeneratedMediaType.audio;
    }

    return GeneratedMediaType.unknown;
  }
}

class GeneratedMediaItem {
  final String url;
  final String modelId;
  final String modelName;
  final String prompt;
  final int pointsCost;
  final DateTime createdAt;

  /// category from app/backend like: image / video / audio
  final String category;

  /// richer type helper for UI rendering
  final GeneratedMediaType mediaType;

  /// optional provider label for cleaner UI
  final String provider;

  /// optional prediction id if returned by backend
  final String? predictionId;

  /// optional mime type if known later
  final String? mimeType;

  /// all output urls from same generation run
  final List<String> allUrls;

  /// optional extra generation metadata
  final Map<String, dynamic> metadata;

  const GeneratedMediaItem({
    required this.url,
    required this.modelId,
    required this.modelName,
    required this.prompt,
    required this.pointsCost,
    required this.createdAt,
    this.category = 'image',
    this.mediaType = GeneratedMediaType.image,
    this.provider = '',
    this.predictionId,
    this.mimeType,
    this.allUrls = const [],
    this.metadata = const {},
  });

  bool get isImage => mediaType.isImage;
  bool get isVideo => mediaType.isVideo;
  bool get isAudio => mediaType.isAudio;

  String get typeKey => mediaType.key;
  String get typeLabel => mediaType.label;

  bool get hasMultipleOutputs => allUrls.length > 1;

  List<String> get normalizedUrls {
    final set = <String>{};
    if (url.trim().isNotEmpty) {
      set.add(url.trim());
    }
    for (final item in allUrls) {
      final v = item.trim();
      if (v.isNotEmpty) {
        set.add(v);
      }
    }
    return set.toList(growable: false);
  }

  String? get localFilePath {
    final raw = metadata['localFilePath']?.toString().trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  String get remoteUrl {
    if (url.trim().isNotEmpty) return url.trim();
    final urls = normalizedUrls;
    return urls.isEmpty ? '' : urls.first;
  }

  String get previewUrl {
    final local = localFilePath;
    if (local != null && local.isNotEmpty) return local;
    return remoteUrl;
  }

  GeneratedMediaItem copyWith({
    String? url,
    String? modelId,
    String? modelName,
    String? prompt,
    int? pointsCost,
    DateTime? createdAt,
    String? category,
    GeneratedMediaType? mediaType,
    String? provider,
    String? predictionId,
    String? mimeType,
    List<String>? allUrls,
    Map<String, dynamic>? metadata,
  }) {
    return GeneratedMediaItem(
      url: url ?? this.url,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
      prompt: prompt ?? this.prompt,
      pointsCost: pointsCost ?? this.pointsCost,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      mediaType: mediaType ?? this.mediaType,
      provider: provider ?? this.provider,
      predictionId: predictionId ?? this.predictionId,
      mimeType: mimeType ?? this.mimeType,
      allUrls: allUrls ?? this.allUrls,
      metadata: metadata ?? this.metadata,
    );
  }

  factory GeneratedMediaItem.fromOutput({
    required String url,
    required String modelId,
    required String modelName,
    required String prompt,
    required int pointsCost,
    required DateTime createdAt,
    String category = 'image',
    String provider = '',
    String? predictionId,
    String? mimeType,
    List<String> allUrls = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    final typeFromCategory = GeneratedMediaType.fromCategory(category);
    final inferredType = typeFromCategory == GeneratedMediaType.unknown
        ? GeneratedMediaType.fromUrl(url)
        : typeFromCategory;

    return GeneratedMediaItem(
      url: url,
      modelId: modelId,
      modelName: modelName,
      prompt: prompt,
      pointsCost: pointsCost,
      createdAt: createdAt,
      category: category,
      mediaType: inferredType,
      provider: provider,
      predictionId: predictionId,
      mimeType: mimeType,
      allUrls: allUrls,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'modelId': modelId,
      'modelName': modelName,
      'prompt': prompt,
      'pointsCost': pointsCost,
      'createdAt': createdAt.toIso8601String(),
      'category': category,
      'mediaType': mediaType.key,
      'provider': provider,
      'predictionId': predictionId,
      'mimeType': mimeType,
      'allUrls': allUrls,
      'metadata': metadata,
    };
  }

  factory GeneratedMediaItem.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['allUrls'];
    final urls = rawUrls is List
        ? rawUrls.map((e) => e?.toString() ?? '').where((e) => e.trim().isNotEmpty).toList(growable: false)
        : const <String>[];

    final category = (json['category'] ?? '').toString();
    final mediaTypeRaw = (json['mediaType'] ?? '').toString();

    GeneratedMediaType mediaType;
    switch (mediaTypeRaw.trim().toLowerCase()) {
      case 'image':
        mediaType = GeneratedMediaType.image;
        break;
      case 'video':
        mediaType = GeneratedMediaType.video;
        break;
      case 'audio':
        mediaType = GeneratedMediaType.audio;
        break;
      default:
        final url = (json['url'] ?? '').toString();
        final byCategory = GeneratedMediaType.fromCategory(category);
        mediaType = byCategory == GeneratedMediaType.unknown
            ? GeneratedMediaType.fromUrl(url)
            : byCategory;
    }

    return GeneratedMediaItem(
      url: (json['url'] ?? '').toString(),
      modelId: (json['modelId'] ?? '').toString(),
      modelName: (json['modelName'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      pointsCost: _toInt(json['pointsCost']),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      category: category.isEmpty ? mediaType.key : category,
      mediaType: mediaType,
      provider: (json['provider'] ?? '').toString(),
      predictionId: json['predictionId']?.toString(),
      mimeType: json['mimeType']?.toString(),
      allUrls: urls,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}