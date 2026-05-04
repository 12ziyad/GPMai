import 'package:flutter/material.dart';
import '../../models/or_models.dart';
import '../../stores/models_store.dart';
import 'model_detail_page.dart';
import 'models_extras.dart';

class ModelsHubPage extends StatefulWidget {
  const ModelsHubPage({super.key});

  @override
  State<ModelsHubPage> createState() => _ModelsHubPageState();
}

class _ModelsHubPageState extends State<ModelsHubPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    // initial refresh is triggered when scope is mounted (call from parent after wiring).
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ModelsScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        actions: [
          IconButton(
            tooltip: 'Compare',
            onPressed: store.compareList.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModelsScope(
                          store: store,
                          child: CompareModelsPage(models: store.compareList),
                        ),
                      ),
                    );
                  },
            icon: Badge(
              isLabelVisible: store.compareList.isNotEmpty,
              label: Text('${store.compareList.length}'),
              child: const Icon(Icons.compare_arrows_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: store.loading ? null : () => store.refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryTabs(store: store),
          _SearchAndSortRow(store: store, controller: _searchCtrl),
          _ProvidersHeaderRow(store: store),
          _ProviderChipsRow(store: store),
          const Divider(height: 1),
          Expanded(child: _ModelsList(store: store)),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final ModelsStore store;
  const _CategoryTabs({required this.store});

  @override
  Widget build(BuildContext context) {
    final tabs = <(ModelCategory, String)>[
      (ModelCategory.all, 'All'),
      (ModelCategory.chat, 'Chat'),
      (ModelCategory.image, 'Image'),
      (ModelCategory.audio, 'Audio'),
      (ModelCategory.video, 'Video'),
      (ModelCategory.tools, 'Tools'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final (cat, label) = tabs[i];
          final selected = store.category == cat;
          return ChoiceChip(
            selected: selected,
            label: Text(label),
            onSelected: (_) {
              store.setCategory(cat);
              store.refresh();
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: tabs.length,
      ),
    );
  }
}

class _SearchAndSortRow extends StatelessWidget {
  final ModelsStore store;
  final TextEditingController controller;
  const _SearchAndSortRow({required this.store, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (v) {
                store.setSearch(v);
                store.refresh();
              },
              decoration: InputDecoration(
                hintText: 'Search 600+ models…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          controller.clear();
                          store.setSearch('');
                          store.refresh();
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SortButton(store: store),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final ModelsStore store;
  const _SortButton({required this.store});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ModelSort>(
      tooltip: 'Sort',
      initialValue: store.sort,
      onSelected: (s) {
        store.setSort(s);
        store.refresh();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: ModelSort.recommended, child: Text('Recommended')),
        PopupMenuItem(value: ModelSort.az, child: Text('A–Z')),
        PopupMenuItem(value: ModelSort.provider, child: Text('Provider')),
        PopupMenuItem(value: ModelSort.contextDesc, child: Text('Highest context')),
        PopupMenuItem(value: ModelSort.priceAsc, child: Text('Cheapest first')),
        PopupMenuItem(value: ModelSort.priceDesc, child: Text('Premium first')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.sort_rounded),
      ),
    );
  }
}

class _ProvidersHeaderRow extends StatelessWidget {
  final ModelsStore store;
  const _ProvidersHeaderRow({required this.store});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: Row(
        children: [
          const Text('Providers', style: TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ModelsScope(store: store, child: const ProvidersSheet()),
              );
            },
            child: const Text('See all'),
          ),
        ],
      ),
    );
  }
}

class _ProviderChipsRow extends StatelessWidget {
  final ModelsStore store;
  const _ProviderChipsRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final providers = store.providers;
    // show only top few in chips row, rest in sheet
    final top = providers.take(10).toList();

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          if (i == 0) {
            final selected = store.providerSlug == null;
            return ChoiceChip(
              selected: selected,
              label: const Text('All Providers'),
              onSelected: (_) {
                store.setProvider(null);
                store.refresh();
              },
            );
          }
          final p = top[i - 1];
          final selected = store.providerSlug == p.slug;

          // If category not all, show only providers that have that category count > 0
          if (store.category != ModelCategory.all && p.countFor(store.category) <= 0) {
            // still include chip? your call — I hide to keep it smart
            return const SizedBox.shrink();
          }

          return ChoiceChip(
            selected: selected,
            label: Text(p.label),
            onSelected: (_) {
              store.setProvider(p.slug);
              store.refresh();
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: 1 + top.length,
      ),
    );
  }
}

class _ModelsList extends StatelessWidget {
  final ModelsStore store;
  const _ModelsList({required this.store});

  @override
  Widget build(BuildContext context) {
    if (store.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (store.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error: ${store.error}'),
        ),
      );
    }

    final models = store.visibleModels;
    if (models.isEmpty) {
      return const Center(child: Text('No models found.'));
    }

    return ListView.builder(
      itemCount: models.length,
      itemBuilder: (_, i) {
        final m = models[i];
        return _ModelTile(
          model: m,
          store: store,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ModelsScope(
                  store: store,
                  child: ModelDetailPage(model: m),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ModelTile extends StatelessWidget {
  final ORModel model;
  final ModelsStore store;
  final VoidCallback onTap;

  const _ModelTile({
    required this.model,
    required this.store,
    required this.onTap,
  });

  IconData _iconFor(ModelCategory c) {
    switch (c) {
      case ModelCategory.image:
        return Icons.image_rounded;
      case ModelCategory.audio:
        return Icons.graphic_eq_rounded;
      case ModelCategory.video:
        return Icons.video_collection_rounded;
      case ModelCategory.tools:
        return Icons.handyman_rounded;
      case ModelCategory.chat:
      case ModelCategory.all:
      case ModelCategory.other:
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inCompare = store.isInCompare(model.id);

    return ListTile(
      leading: Icon(_iconFor(model.category)),
      title: Text(model.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${model.providerLabel} • ${model.id}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model.contextLength > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text('${model.contextLength} ctx', style: const TextStyle(fontSize: 12)),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Compare (max 3)',
            onPressed: () => store.toggleCompare(model),
            icon: Icon(inCompare ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
