import 'dart:convert';

enum ModelCategory { all, chat, image, audio, video, tools, other }
enum ModelSort { recommended, az, provider, contextDesc, priceAsc, priceDesc }

ModelCategory parseCategory(String raw) {
  final v = raw.trim().toLowerCase();
  switch (v) {
    case 'chat':
      return ModelCategory.chat;
    case 'image':
      return ModelCategory.image;
    case 'audio':
      return ModelCategory.audio;
    case 'video':
      return ModelCategory.video;
    case 'tools':
      return ModelCategory.tools;
    case 'other':
      return ModelCategory.other;
    case 'all':
    default:
      return ModelCategory.all;
  }
}

String categoryToQuery(ModelCategory c) {
  switch (c) {
    case ModelCategory.chat:
      return 'chat';
    case ModelCategory.image:
      return 'image';
    case ModelCategory.audio:
      return 'audio';
    case ModelCategory.video:
      return 'video';
    case ModelCategory.tools:
      return 'tools';
    case ModelCategory.other:
      return 'other';
    case ModelCategory.all:
    default:
      return 'all';
  }
}

ModelSort parseSort(String raw) {
  final v = raw.trim().toLowerCase();
  switch (v) {
    case 'az':
      return ModelSort.az;
    case 'provider':
      return ModelSort.provider;
    case 'context_desc':
      return ModelSort.contextDesc;
    case 'price_asc':
      return ModelSort.priceAsc;
    case 'price_desc':
      return ModelSort.priceDesc;
    case 'recommended':
    default:
      return ModelSort.recommended;
  }
}

String sortToQuery(ModelSort s) {
  switch (s) {
    case ModelSort.az:
      return 'az';
    case ModelSort.provider:
      return 'provider';
    case ModelSort.contextDesc:
      return 'context_desc';
    case ModelSort.priceAsc:
      return 'price_asc';
    case ModelSort.priceDesc:
      return 'price_desc';
    case ModelSort.recommended:
    default:
      return 'recommended';
  }
}

class ORProvider {
  final String slug;
  final String label;
  final int total;
  final Map<String, int> categoriesCount;

  const ORProvider({
    required this.slug,
    required this.label,
    required this.total,
    required this.categoriesCount,
  });

  int countFor(ModelCategory c) {
    final key = categoryToQuery(c);
    return categoriesCount[key] ?? 0;
  }

  factory ORProvider.fromJson(Map<String, dynamic> j) {
    final cc = <String, int>{};
    final raw = (j['categoriesCount'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final e in raw.entries) {
      cc[e.key] = (e.value is num) ? (e.value as num).toInt() : 0;
    }
    return ORProvider(
      slug: (j['slug'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      total: (j['total'] is num) ? (j['total'] as num).toInt() : 0,
      categoriesCount: cc,
    );
  }
}

class ORModel {
  final String id;
  final String name;
  final String provider;
  final String providerLabel;
  final ModelCategory category;
  final int contextLength;
  final String priceTier; // budget|standard|premium|unknown
  final Map<String, dynamic>? pricing;

  const ORModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.providerLabel,
    required this.category,
    required this.contextLength,
    required this.priceTier,
    required this.pricing,
  });

  factory ORModel.fromJson(Map<String, dynamic> j) {
    return ORModel(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      provider: (j['provider'] ?? '').toString(),
      providerLabel: (j['providerLabel'] ?? '').toString(),
      category: parseCategory((j['category'] ?? 'chat').toString()),
      contextLength: (j['contextLength'] is num) ? (j['contextLength'] as num).toInt() : 0,
      priceTier: (j['priceTier'] ?? 'unknown').toString(),
      pricing: (j['pricing'] is Map) ? (j['pricing'] as Map).cast<String, dynamic>() : null,
    );
  }
}

class ModelsCatalog {
  final int ts;
  final int ttlMs;
  final Map<String, int> categoriesCount;
  final List<ORProvider> providers;
  final List<ORModel> models;

  const ModelsCatalog({
    required this.ts,
    required this.ttlMs,
    required this.categoriesCount,
    required this.providers,
    required this.models,
  });

  factory ModelsCatalog.fromJson(Map<String, dynamic> j) {
    final providersRaw = (j['providers'] as List?)?.cast<dynamic>() ?? const [];
    final modelsRaw = (j['all'] as List?)?.cast<dynamic>() ?? const [];
    final cats = <String, int>{};

    final rawCats = (j['categoriesCount'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final e in rawCats.entries) {
      cats[e.key] = (e.value is num) ? (e.value as num).toInt() : 0;
    }

    return ModelsCatalog(
      ts: (j['ts'] is num) ? (j['ts'] as num).toInt() : 0,
      ttlMs: (j['ttlMs'] is num) ? (j['ttlMs'] as num).toInt() : 0,
      categoriesCount: cats,
      providers: providersRaw.map((x) => ORProvider.fromJson((x as Map).cast<String, dynamic>())).toList(),
      models: modelsRaw.map((x) => ORModel.fromJson((x as Map).cast<String, dynamic>())).toList(),
    );
  }

  static ModelsCatalog fromJsonString(String s) =>
      ModelsCatalog.fromJson(json.decode(s) as Map<String, dynamic>);
}
