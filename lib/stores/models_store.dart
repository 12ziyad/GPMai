import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/or_models.dart';
import '../services/models_api.dart';

class ModelsStore extends ChangeNotifier {
  final ModelsApi api;

  ModelsStore({required this.api});

  // State
  bool _loading = false;
  String? _error;

  ModelCategory _category = ModelCategory.all;
  String? _providerSlug; // null = all providers
  ModelSort _sort = ModelSort.recommended;
  String _search = '';

  // Data
  ModelsCatalog? _catalog;

  // Compare
  final List<ORModel> _compare = [];

  bool get loading => _loading;
  String? get error => _error;

  ModelCategory get category => _category;
  String? get providerSlug => _providerSlug;
  ModelSort get sort => _sort;
  String get search => _search;

  ModelsCatalog? get catalog => _catalog;

  List<ORProvider> get providers => _catalog?.providers ?? const [];
  Map<String, int> get categoriesCount => _catalog?.categoriesCount ?? const {};
  int get totalModels => _catalog?.models.length ?? 0;

  List<ORModel> get visibleModels {
    final list = _catalog?.models ?? const <ORModel>[];

    Iterable<ORModel> out = list;

    if (_category != ModelCategory.all) {
      out = out.where((m) => m.category == _category);
    }

    if (_providerSlug != null && _providerSlug!.isNotEmpty) {
      final p = _providerSlug!;
      out = out.where((m) => m.provider == p);
    }

    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((m) {
        final s = '${m.name} ${m.id} ${m.providerLabel} ${m.provider}'.toLowerCase();
        return s.contains(q);
      });
    }

    // Sort locally for instant UX (even if server sorts)
    final arr = out.toList(growable: false);
    return _sortLocal(arr, _sort);
  }

  List<ORModel> get compareList => List.unmodifiable(_compare);

  bool isInCompare(String id) => _compare.any((m) => m.id == id);

  void toggleCompare(ORModel m) {
    final idx = _compare.indexWhere((x) => x.id == m.id);
    if (idx >= 0) {
      _compare.removeAt(idx);
    } else {
      if (_compare.length >= 3) return; // hard cap
      _compare.add(m);
    }
    notifyListeners();
  }

  void clearCompare() {
    _compare.clear();
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final cat = _category;
      final prov = _providerSlug;
      final sort = _sort;
      final q = _search;

      // For speed, we can fetch "all" once and filter locally.
      // BUT your worker already supports query params, so we fetch what the UI currently needs.
      final catalog = await api.getModels(
        category: cat,
        providerSlug: prov,
        sort: sort,
        q: q.isEmpty ? null : q,
      );

      _catalog = catalog;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setCategory(ModelCategory c) {
    if (_category == c) return;
    _category = c;
    // When changing category, keep provider slug but UI sheet counts will guide selection.
    notifyListeners();
  }

  void setProvider(String? slug) {
    final s = (slug == null || slug.trim().isEmpty) ? null : slug.trim().toLowerCase();
    if (_providerSlug == s) return;
    _providerSlug = s;
    notifyListeners();
  }

  void setSort(ModelSort s) {
    if (_sort == s) return;
    _sort = s;
    notifyListeners();
  }

  void setSearch(String v) {
    final nv = v;
    if (_search == nv) return;
    _search = nv;
    notifyListeners();
  }

  void clearFilters() {
    _category = ModelCategory.all;
    _providerSlug = null;
    _sort = ModelSort.recommended;
    _search = '';
    notifyListeners();
  }

  List<ORModel> _sortLocal(List<ORModel> arr, ModelSort sort) {
    switch (sort) {
      case ModelSort.az:
        arr.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return arr;
      case ModelSort.provider:
        arr.sort((a, b) {
          final c = a.providerLabel.toLowerCase().compareTo(b.providerLabel.toLowerCase());
          if (c != 0) return c;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return arr;
      case ModelSort.contextDesc:
        arr.sort((a, b) {
          final c = b.contextLength.compareTo(a.contextLength);
          if (c != 0) return c;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return arr;
      case ModelSort.priceAsc:
        arr.sort((a, b) => _tierRank(a.priceTier).compareTo(_tierRank(b.priceTier)));
        return arr;
      case ModelSort.priceDesc:
        arr.sort((a, b) => _tierRank(b.priceTier).compareTo(_tierRank(a.priceTier)));
        return arr;
      case ModelSort.recommended:
      default:
        // Server already recommends. Keep stable:
        arr.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return arr;
    }
  }

  int _tierRank(String t) {
    switch (t) {
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
}

/// Simple scope without provider package.
class ModelsScope extends InheritedNotifier<ModelsStore> {
  const ModelsScope({
    super.key,
    required ModelsStore store,
    required super.child,
  }) : super(notifier: store);

  static ModelsStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ModelsScope>();
    assert(scope != null, 'ModelsScope not found in widget tree');
    return scope!.notifier!;
  }
}
