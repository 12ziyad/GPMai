import '../models/or_models.dart';
import 'curated_models.dart';

typedef JsonFetcher = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, String> query,
);

class ModelsApi {
  final JsonFetcher fetchJson;

  ModelsApi({required this.fetchJson});

  Future<ModelsCatalog> getModels({
    ModelCategory category = ModelCategory.all,
    String? providerSlug,
    ModelSort sort = ModelSort.recommended,
    String? q,
  }) async {
    final liveJson = await fetchJson(
      '/models',
      <String, String>{
        'category': 'all',
        'sort': 'recommended',
      },
    );

    final liveCatalog = ModelsCatalog.fromJson(liveJson);
    final liveModels = liveCatalog.models;

    final resolvedModels = <ORModel>[];

    for (final curated in curatedOfficialModels) {
      final matched = _resolveCuratedModel(curated, liveModels);

      if (matched != null) {
        resolvedModels.add(matched);
      } else {
        resolvedModels.add(
          ORModel(
            id: curated.preferredId,
            name: curated.displayName,
            provider: _providerSlug(curated.provider),
            providerLabel: curated.provider,
            category: ModelCategory.chat,
            contextLength: 0,
            priceTier: curated.popular ? 'standard' : 'unknown',
            pricing: null,
          ),
        );
      }
    }

    Iterable<ORModel> filtered = resolvedModels;

    if (category != ModelCategory.all) {
      filtered = filtered.where((m) => m.category == category);
    }

    if (providerSlug != null && providerSlug.trim().isNotEmpty) {
      final slug = providerSlug.trim().toLowerCase();
      filtered = filtered.where((m) => m.provider.toLowerCase() == slug);
    }

    if (q != null && q.trim().isNotEmpty) {
      final queryNeedle = q.trim().toLowerCase();
      filtered = filtered.where((m) {
        final hay =
            '${m.name} ${m.providerLabel} ${m.provider} ${m.id}'.toLowerCase();
        return hay.contains(queryNeedle);
      });
    }

    final models = filtered.toList();
    _sortModels(models, sort);

    final providersMap = <String, List<ORModel>>{};
    for (final m in models) {
      providersMap.putIfAbsent(m.provider, () => []).add(m);
    }

    final providers = providersMap.entries.map((e) {
      final first = e.value.first;
      return ORProvider(
        slug: first.provider,
        label: first.providerLabel,
        total: e.value.length,
        categoriesCount: {
          'all': e.value.length,
          'chat': e.value.where((x) => x.category == ModelCategory.chat).length,
          'image': e.value.where((x) => x.category == ModelCategory.image).length,
          'audio': e.value.where((x) => x.category == ModelCategory.audio).length,
          'video': e.value.where((x) => x.category == ModelCategory.video).length,
          'tools': e.value.where((x) => x.category == ModelCategory.tools).length,
          'other': e.value.where((x) => x.category == ModelCategory.other).length,
        },
      );
    }).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    final categoriesCount = <String, int>{
      'all': models.length,
      'chat': models.where((m) => m.category == ModelCategory.chat).length,
      'image': models.where((m) => m.category == ModelCategory.image).length,
      'audio': models.where((m) => m.category == ModelCategory.audio).length,
      'video': models.where((m) => m.category == ModelCategory.video).length,
      'tools': models.where((m) => m.category == ModelCategory.tools).length,
      'other': models.where((m) => m.category == ModelCategory.other).length,
    };

    return ModelsCatalog(
      ts: liveCatalog.ts,
      ttlMs: liveCatalog.ttlMs,
      categoriesCount: categoriesCount,
      providers: providers,
      models: models,
    );
  }

  ORModel? _resolveCuratedModel(CuratedModel curated, List<ORModel> liveModels) {
    final provider = _providerSlug(curated.provider);
    final byProvider = liveModels
        .where((m) => m.provider.toLowerCase() == provider)
        .toList();

    // 1) exact preferred id
    for (final m in byProvider) {
      if (m.id.trim().toLowerCase() == curated.preferredId.trim().toLowerCase()) {
        return m;
      }
    }

    final exactDisplay = _normalize(curated.displayName);

    // 2) normalized exact display name
    for (final m in byProvider) {
      if (_normalize(m.name) == exactDisplay) {
        return m;
      }
    }

    // 3) aliases
    for (final alias in curated.normalizedAliases) {
      for (final m in byProvider) {
        if (_normalize(m.name) == alias) {
          return m;
        }
      }
    }

    // 4) contains match against display name
    for (final m in byProvider) {
      final liveName = _normalize(m.name);
      if (liveName.contains(exactDisplay) || exactDisplay.contains(liveName)) {
        return m;
      }
    }

    // 5) contains match against aliases
    for (final alias in curated.normalizedAliases) {
      for (final m in byProvider) {
        final liveName = _normalize(m.name);
        if (liveName.contains(alias) || alias.contains(liveName)) {
          return m;
        }
      }
    }

    return null;
  }

  void _sortModels(List<ORModel> models, ModelSort sort) {
    switch (sort) {
      case ModelSort.az:
        models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return;

      case ModelSort.provider:
        models.sort((a, b) {
          final p = a.providerLabel.toLowerCase().compareTo(b.providerLabel.toLowerCase());
          if (p != 0) return p;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return;

      case ModelSort.contextDesc:
        models.sort((a, b) => b.contextLength.compareTo(a.contextLength));
        return;

      case ModelSort.priceAsc:
        models.sort((a, b) => _tierRank(a.priceTier).compareTo(_tierRank(b.priceTier)));
        return;

      case ModelSort.priceDesc:
        models.sort((a, b) => _tierRank(b.priceTier).compareTo(_tierRank(a.priceTier)));
        return;

      case ModelSort.recommended:
      default:
        final popularity = <String, int>{
          for (final m in curatedOfficialModels) m.preferredId: m.popular ? 1 : 0,
        };

        models.sort((a, b) {
          final pa = popularity[a.id] ?? 0;
          final pb = popularity[b.id] ?? 0;
          if (pb != pa) return pb.compareTo(pa);

          final pr = _providerRank(b.provider) - _providerRank(a.provider);
          if (pr != 0) return pr;

          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }
  }

  int _tierRank(String tier) {
    switch (tier) {
      case 'budget':
        return 0;
      case 'standard':
        return 1;
      case 'premium':
        return 2;
      default:
        return 9;
    }
  }

  int _providerRank(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 10;
      case 'anthropic':
        return 9;
      case 'google':
        return 8;
      case 'deepseek':
        return 7;
      case 'xai':
        return 6;
      case 'mistral':
      case 'mistralai':
        return 5;
      case 'qwen':
        return 4;
      case 'cohere':
        return 3;
      case 'amazon':
        return 2;
      default:
        return 1;
    }
  }

  String _providerSlug(String provider) {
    final v = provider.trim().toLowerCase();
    switch (v) {
      case 'openai':
        return 'openai';
      case 'anthropic':
        return 'anthropic';
      case 'google':
        return 'google';
      case 'xai':
      case 'x.ai':
        return 'x-ai';
      case 'deepseek':
        return 'deepseek';
      case 'mistral':
        return 'mistralai';
      case 'cohere':
        return 'cohere';
      case 'amazon':
        return 'amazon';
      case 'qwen':
        return 'qwen';
      case 'z.ai':
        return 'z-ai';
      case 'moonshotai':
        return 'moonshotai';
      case 'minimax':
        return 'minimax';
      case 'arcee ai':
        return 'arcee-ai';
      default:
        return v.replaceAll(' ', '-');
    }
  }
}

String _normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'\(.*?\)'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}