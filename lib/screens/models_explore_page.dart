import 'package:flutter/material.dart';

import '../services/curated_models.dart';
import '../services/curated_media_models.dart';
import '../services/provider_branding.dart';
import '../spaces/audio_generator_page.dart';
import '../spaces/image_generator_page.dart';
import '../spaces/video_generator_page.dart';
import 'model_info_page.dart';

class ModelsExplorePage extends StatefulWidget {
  final String initialCategory;

  final void Function(CuratedModel model)? onModelTap;
  final void Function(CuratedMediaModel model)? onMediaModelTap;

  const ModelsExplorePage({
    super.key,
    this.initialCategory = 'chat',
    this.onModelTap,
    this.onMediaModelTap,
  });

  @override
  State<ModelsExplorePage> createState() => _ModelsExplorePageState();
}

class _ModelsExplorePageState extends State<ModelsExplorePage> {
  late final TextEditingController _searchCtrl;
  late String _selectedCategory;

  static const List<String> _categories = <String>[
    'chat',
    'image',
    'audio',
    'video',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _selectedCategory = _normalizeCategory(widget.initialCategory);
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalizeCategory(String raw) {
    final v = raw.trim().toLowerCase();
    if (_categories.contains(v)) return v;
    return 'chat';
  }

  bool get _isSearching => _searchCtrl.text.trim().isNotEmpty;

  List<CuratedModel> _filteredChatModels() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final source = mixedOfficialModels;

    if (query.isEmpty) return source;

    return source.where((m) {
      final hay = [
        m.id,
        m.displayName,
        m.provider,
        m.description,
        m.providerKey,
        ...m.aliases,
      ].join(' ').toLowerCase();

      return hay.contains(query);
    }).toList(growable: false);
  }

  List<CuratedMediaModel> _sourceMediaModels(String category) {
    switch (category) {
      case 'image':
        return imageModels;
      case 'audio':
        return audioModels;
      case 'video':
        return videoModels;
      default:
        return CuratedMediaCatalog.allModels;
    }
  }

  List<CuratedMediaModel> _featuredMediaModels(String category) {
    return _sourceMediaModels(category)
        .where((m) => m.isFeatured)
        .toList(growable: false);
  }

  List<CuratedMediaModel> _filteredMediaModels(String category) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final source = _sourceMediaModels(category);

    if (query.isEmpty) return source;

    return source.where((m) {
      final hay = [
        m.id,
        m.name,
        m.provider,
        m.description,
        ...m.tags,
        m.categoryKey,
        m.categoryLabel,
        m.badge ?? '',
      ].join(' ').toLowerCase();

      return hay.contains(query);
    }).toList(growable: false);
  }

  Future<void> _handleChatModelTap(CuratedModel model) async {
    if (widget.onModelTap != null) {
      widget.onModelTap!(model);
      return;
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModelInfoPage(model: model),
      ),
    );
  }

  Future<void> _handleMediaModelTap(CuratedMediaModel model) async {
    if (widget.onMediaModelTap != null) {
      widget.onMediaModelTap!(model);
      return;
    }

    if (!mounted) return;

    switch (model.category) {
      case MediaCategory.image:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImageGeneratorPage(initialModel: model),
          ),
        );
        break;
      case MediaCategory.audio:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AudioGeneratorPage(initialModel: model),
          ),
        );
        break;
      case MediaCategory.video:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoGeneratorPage(initialModel: model),
          ),
        );
        break;
    }
  }

  Color _providerColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return const Color(0xFFFF4DA6);
      case 'anthropic':
        return const Color(0xFFFF9F1C);
      case 'google':
        return const Color(0xFF42A5F5);
      case 'meta':
      case 'meta-llama':
        return const Color(0xFF00BFA6);
      case 'mistral':
      case 'mistralai':
        return const Color(0xFF7E57C2);
      case 'xai':
      case 'grok':
        return const Color(0xFFE53935);
      case 'deepseek':
        return const Color(0xFF7FA8FF);
      case 'qwen':
        return const Color(0xFF6BE4FF);
      case 'cohere':
        return const Color(0xFF8BFFB3);
      case 'minimax':
        return const Color(0xFF63E6BE);
      case 'replicate':
        return const Color(0xFF8B5CF6);
      case 'elevenlabs':
        return const Color(0xFFFFB84D);
      case 'stability ai':
      case 'stability-ai':
        return const Color(0xFFB197FC);
      default:
        return const Color(0xFF90A4AE);
    }
  }


  List<Color> _brandGradient(Color accent) => [
    accent.withOpacity(.26),
    accent.withOpacity(.14),
    const Color(0xFF090B10),
  ];

  String _providerInitials(String provider) {
    final cleaned = provider.trim();
    if (cleaned.isEmpty) return '?';

    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'chat':
        return Icons.forum_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'audio':
        return Icons.graphic_eq_rounded;
      case 'video':
        return Icons.videocam_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String _titleForCategory(String category) {
    switch (category) {
      case 'chat':
        return 'Official Models';
      case 'image':
        return 'Image Models';
      case 'audio':
        return 'Audio Models';
      case 'video':
        return 'Video Models';
      default:
        return 'Models';
    }
  }

  String _subtitleForCategory(String category) {
    switch (category) {
      case 'chat':
        return 'Curated premium chat and reasoning models';
      case 'image':
        return 'Prompt, edit, and reference-image models. Capability badges are shown on each model tile.';
      case 'audio':
        return 'Speech, music, and sound generation models';
      case 'video':
        return 'Text-to-video and image-to-video models. Look for the capability badges on each tile.';
      default:
        return 'Explore curated models';
    }
  }

  Widget _buildCategoryPills() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final selected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: selected
                      ? cs.primary.withOpacity(isLight ? 0.14 : 0.18)
                      : (isLight
                          ? Colors.black.withOpacity(0.04)
                          : Colors.white.withOpacity(0.05)),
                  border: Border.all(
                    color: selected
                        ? cs.primary
                        : (isLight ? Colors.black12 : Colors.white12),
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconForCategory(category),
                      size: 17,
                      color: selected
                          ? cs.primary
                          : (isLight ? Colors.black54 : Colors.white60),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _titleForCategory(category).replaceAll(' Models', ''),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? cs.primary
                            : (isLight ? Colors.black87 : Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildHeader() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final title = _titleForCategory(_selectedCategory);
    final subtitle = _subtitleForCategory(_selectedCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isLight ? Colors.black54 : Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      decoration: BoxDecoration(
        color: isLight
            ? Colors.black.withOpacity(.04)
            : Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLight ? Colors.black12 : Colors.white12,
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search models, providers, categories...',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _isSearching
              ? IconButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                  },
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        ),
      ),
    );
  }

  Widget _buildCountText(int count) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Text(
      '$count model${count == 1 ? '' : 's'}',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isLight ? Colors.black54 : Colors.white60,
      ),
    );
  }

  Widget _buildChatList(List<CuratedModel> items) {
    if (items.isEmpty) {
      return const _EmptyState(
        title: 'No chat models found',
        subtitle: 'Try another keyword or switch category.',
        icon: Icons.forum_rounded,
      );
    }

    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final model = items[index];
        final brand = ProviderBranding.resolve(provider: model.provider, modelId: model.id, displayName: model.displayName);

        return _ExploreModelTile(
          icon: brand.initials(model.provider),
          iconColor: brand.accent,
          brand: brand,
          title: model.displayName,
          subtitle: model.description,
          provider: model.provider.toLowerCase() == 'replicate' ? '' : model.provider,
          badge: model.popular ? 'Popular' : 'Official',
          tags: [
            if (model.supportsReasoning) 'Reasoning',
            if (model.supportsVision) 'Vision',
            if (model.supportsCoding) 'Coding',
            if (model.supportsTools) 'Tools',
          ],
          onTap: () => _handleChatModelTap(model),
        );
      },
    );
  }

  Widget _buildFeaturedMediaRow(List<CuratedMediaModel> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final model = items[index];
              final brand = ProviderBranding.resolve(provider: model.provider, modelId: model.id, displayName: model.name);

              return _FeaturedMediaCard(
                model: model,
                brand: brand,
                onTap: () => _handleMediaModelTap(model),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaList(List<CuratedMediaModel> items) {
    if (items.isEmpty) {
      return _EmptyState(
        title: 'No media models found',
        subtitle: 'Try another keyword or switch category.',
        icon: _iconForCategory(_selectedCategory),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final model = items[index];
        final brand = ProviderBranding.resolve(provider: model.provider, modelId: model.id, displayName: model.name);

        return _ExploreModelTile(
          iconData: _iconForCategory(model.categoryKey),
          iconColor: brand.accent,
          brand: brand,
          title: model.name,
          subtitle: model.description,
          provider: '',
          badge: model.badge ?? model.categoryLabel,
          tags: [model.providerBadge, ...model.capabilityBadges, ...model.tags].take(4).toList(growable: false),
          onTap: () => _handleMediaModelTap(model),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatItems =
        _selectedCategory == 'chat' ? _filteredChatModels() : const <CuratedModel>[];
    final mediaItems = _selectedCategory == 'chat'
        ? const <CuratedMediaModel>[]
        : _filteredMediaModels(_selectedCategory);
    final featuredMediaItems = _selectedCategory == 'chat' || _isSearching
        ? const <CuratedMediaModel>[]
        : _featuredMediaModels(_selectedCategory);

    final totalCount =
        _selectedCategory == 'chat' ? chatItems.length : mediaItems.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Models'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildCategoryPills(),
            const SizedBox(height: 14),
            _buildSearchField(),
            const SizedBox(height: 14),
            _buildCountText(totalCount),
            const SizedBox(height: 14),
            if (_selectedCategory == 'chat') _buildChatList(chatItems),
            if (_selectedCategory != 'chat') ...[
              _buildFeaturedMediaRow(featuredMediaItems),
              if (featuredMediaItems.isNotEmpty) const SizedBox(height: 18),
              _buildMediaList(mediaItems),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeaturedMediaCard extends StatelessWidget {
  final CuratedMediaModel model;
  final ProviderBranding brand;
  final VoidCallback onTap;

  const _FeaturedMediaCard({
    required this.model,
    required this.brand,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = brand.accent;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: brand.vividGradient(Theme.of(context).brightness),
          ),
          border: Border.all(
            color: brand.border(Theme.of(context).brightness),
          ),
          boxShadow: isLight ? null : [
            BoxShadow(color: color.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              model.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              model.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                height: 1.35,
                color: isLight ? Colors.black54 : Colors.white70,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((model.badge ?? '').trim().isNotEmpty) _TagChip(text: model.badge!),
                ...model.tags.take(1).map((e) => _TagChip(text: e)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreModelTile extends StatelessWidget {
  final String? icon;
  final IconData? iconData;
  final Color iconColor;
  final ProviderBranding? brand;
  final String title;
  final String subtitle;
  final String provider;
  final String badge;
  final List<String> tags;
  final VoidCallback onTap;

  const _ExploreModelTile({
    this.icon,
    this.iconData,
    required this.iconColor,
    this.brand,
    required this.title,
    required this.subtitle,
    required this.provider,
    required this.badge,
    this.tags = const [],
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final palette = brand ?? ProviderBranding.resolve(provider: provider, displayName: title);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: palette.vividGradient(Theme.of(context).brightness)),
          border: Border.all(
            color: palette.border(Theme.of(context).brightness),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isLight ? 0.04 : 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.iconFill(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border(Theme.of(context).brightness)),
              ),
              child: Center(
                child: iconData != null
                    ? Icon(iconData, size: 22, color: palette.accent)
                    : Text(
                        icon ?? '?',
                        style: TextStyle(
                          color: palette.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
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
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                            height: 1.08,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ProviderBadge(
                        label: badge,
                        color: palette.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  if (provider.trim().isNotEmpty)
                    Text(
                      provider,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.accent,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      height: 1.35,
                      color: isLight ? Colors.black54 : Colors.white70,
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.take(4).map((e) => _TagChip(text: e)).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isLight ? Colors.black38 : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ProviderBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;

  const _TagChip({
    required this.text,
  });

  Color _tagColor() {
    final t = text.toLowerCase();
    if (t.contains('image→video') || t.contains('text→video') || t.contains('video')) return const Color(0xFF8B5CF6);
    if (t.contains('image input') || t.contains('edit') || t.contains('reference')) return const Color(0xFF0EA5E9);
    if (t.contains('audio')) return const Color(0xFF10B981);
    if (t.contains('google')) return const Color(0xFF4285F4);
    if (t.contains('grok') || t.contains('xai')) return const Color(0xFF111827);
    if (t.contains('qwen')) return const Color(0xFF7C3AED);
    if (t.contains('minimax')) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = _tagColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLight ? color.withOpacity(.10) : color.withOpacity(.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.42)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: isLight ? color.withOpacity(.95) : color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF12151A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLight ? Colors.black12 : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: isLight ? Colors.black45 : Colors.white54,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.35,
              color: isLight ? Colors.black54 : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
