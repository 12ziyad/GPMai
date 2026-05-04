import 'package:flutter/material.dart';

import '../services/curated_media_models.dart';

class MediaGenerateSheet extends StatefulWidget {
  final List<CuratedMediaModel> models;
  final CuratedMediaModel selected;
  final String? title;
  final String? subtitle;

  const MediaGenerateSheet({
    super.key,
    required this.models,
    required this.selected,
    this.title,
    this.subtitle,
  });

  static Future<CuratedMediaModel?> open(
    BuildContext context, {
    required List<CuratedMediaModel> models,
    required CuratedMediaModel selected,
    String? title,
    String? subtitle,
  }) {
    return showModalBottomSheet<CuratedMediaModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => MediaGenerateSheet(
        models: models,
        selected: selected,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<MediaGenerateSheet> createState() => _MediaGenerateSheetState();
}

class _MediaGenerateSheetState extends State<MediaGenerateSheet> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _query) return;
    setState(() => _query = next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final models = _filteredModels(widget.models, _query);
    final featured = models.where((m) => m.isFeatured).toList(growable: false);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title ?? 'Choose model',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle ??
                        'Pick a production-ready model for your generation flow.',
                    style: TextStyle(
                      height: 1.4,
                      color: scheme.onSurface.withOpacity(.68),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search models, tags, provider...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: scheme.surfaceVariant.withOpacity(.42),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: scheme.outline.withOpacity(.10),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: scheme.outline.withOpacity(.10),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: scheme.primary.withOpacity(.45),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: models.isEmpty
                  ? _EmptyState(query: _query)
                  : CustomScrollView(
                      slivers: [
                        if (featured.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                              child: _SectionHeader(
                                title: 'Featured',
                                subtitle: 'Best picks for fast, polished results',
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 208,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                                scrollDirection: Axis.horizontal,
                                itemCount: featured.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (_, i) {
                                  final model = featured[i];
                                  return _FeaturedModelCard(
                                    model: model,
                                    selected: model.id == widget.selected.id,
                                    onTap: () => Navigator.pop(context, model),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 18),
                          ),
                        ],
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                            child: _SectionHeader(
                              title: 'All models',
                              subtitle: '${models.length} available',
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                          sliver: SliverList.separated(
                            itemCount: models.length,
                            itemBuilder: (_, i) {
                              final model = models[i];
                              return _ModelListTile(
                                model: model,
                                selected: model.id == widget.selected.id,
                                onTap: () => Navigator.pop(context, model),
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static List<CuratedMediaModel> _filteredModels(
    List<CuratedMediaModel> models,
    String query,
  ) {
    if (query.trim().isEmpty) return List<CuratedMediaModel>.from(models);

    return models.where((m) {
      final haystack = [
        m.name,
        m.id,
        m.provider,
        m.description,
        ...m.tags,
        m.categoryLabel,
        m.badge ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList(growable: false);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: scheme.onSurface.withOpacity(.62),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _FeaturedModelCard extends StatelessWidget {
  final CuratedMediaModel model;
  final bool selected;
  final VoidCallback onTap;

  const _FeaturedModelCard({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        width: 290,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withOpacity(.16),
              scheme.secondary.withOpacity(.10),
              scheme.surfaceVariant.withOpacity(.38),
            ],
          ),
          border: Border.all(
            color: selected
                ? scheme.primary.withOpacity(.45)
                : scheme.outline.withOpacity(.10),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderPill(label: model.provider),
                const Spacer(),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              model.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                model.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  height: 1.38,
                  color: scheme.onSurface.withOpacity(.72),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((model.badge ?? '').trim().isNotEmpty)
                  _TinyTag(label: model.badge!.trim()),
                ...model.tags.take(3).map((tag) => _TinyTag(label: tag)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelListTile extends StatelessWidget {
  final CuratedMediaModel model;
  final bool selected;
  final VoidCallback onTap;

  const _ModelListTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: selected
              ? scheme.primary.withOpacity(.08)
              : scheme.surfaceVariant.withOpacity(.22),
          border: Border.all(
            color: selected
                ? scheme.primary.withOpacity(.35)
                : scheme.outline.withOpacity(.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: scheme.primary.withOpacity(.11),
              ),
              child: Icon(
                _iconForCategory(model.category),
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          model.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    model.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      height: 1.35,
                      color: scheme.onSurface.withOpacity(.68),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ProviderPill(label: model.provider),
                      if ((model.badge ?? '').trim().isNotEmpty)
                        _TinyTag(label: model.badge!.trim()),
                      ...model.tags.take(4).map((tag) => _TinyTag(label: tag)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForCategory(MediaCategory category) {
    switch (category) {
      case MediaCategory.image:
        return Icons.image_rounded;
      case MediaCategory.audio:
        return Icons.graphic_eq_rounded;
      case MediaCategory.video:
        return Icons.videocam_rounded;
    }
  }
}

class _ProviderPill extends StatelessWidget {
  final String label;

  const _ProviderPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.primary.withOpacity(.10),
        border: Border.all(
          color: scheme.primary.withOpacity(.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  final String label;

  const _TinyTag({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.surfaceVariant.withOpacity(.55),
        border: Border.all(
          color: scheme.outline.withOpacity(.08),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          color: scheme.onSurface.withOpacity(.82),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;

  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 46,
              color: scheme.onSurface.withOpacity(.5),
            ),
            const SizedBox(height: 14),
            const Text(
              'No matching models',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing matched "$query". Try a different model name, provider, or tag.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.4,
                color: scheme.onSurface.withOpacity(.66),
              ),
            ),
          ],
        ),
      ),
    );
  }
}