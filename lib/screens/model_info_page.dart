import 'package:flutter/material.dart';

import '../services/curated_models.dart';
import '../services/curated_media_models.dart';
import '../services/provider_branding.dart';

class ModelInfoPage extends StatelessWidget {
  final CuratedModel? model;
  final CuratedMediaModel? mediaModel;

  final VoidCallback? onStartChat;
  final VoidCallback? onGenerate;
  final VoidCallback? onOpenHistory;

  const ModelInfoPage({
    super.key,
    this.model,
    this.mediaModel,
    this.onStartChat,
    this.onGenerate,
    this.onOpenHistory,
  }) : assert(model != null || mediaModel != null);

  bool get isChat => model != null;

  String get _title => isChat ? model!.displayName : mediaModel!.name;
  String get _provider => isChat ? model!.provider : mediaModel!.provider;
  String get _description => isChat ? model!.description : mediaModel!.description;

  String get _categoryLabel {
    if (isChat) return 'Chat Model';
    return mediaModel!.categoryLabel;
  }

  String get _primaryActionLabel {
    if (isChat) return 'Start Chat';
    switch (mediaModel!.category) {
      case MediaCategory.image:
        return 'Generate Image';
      case MediaCategory.audio:
        return 'Generate Audio';
      case MediaCategory.video:
        return 'Generate Video';
    }
  }

  IconData get _primaryActionIcon {
    if (isChat) return Icons.chat_bubble_rounded;
    switch (mediaModel!.category) {
      case MediaCategory.image:
        return Icons.image_rounded;
      case MediaCategory.audio:
        return Icons.graphic_eq_rounded;
      case MediaCategory.video:
        return Icons.videocam_rounded;
    }
  }

  List<String> get _chips {
    if (isChat) {
      final out = <String>[];
      if (model!.official) out.add('Official');
      if (model!.popular) out.add('Popular');
      out.add('Chat');
      return out;
    }

    final out = <String>[];
    if (mediaModel!.isOfficial) out.add('Official');
    if (mediaModel!.isFeatured) out.add('Featured');
    if ((mediaModel!.badge ?? '').trim().isNotEmpty) out.add(mediaModel!.badge!);
    if (mediaModel!.supportsEditing) out.add('Editing');
    if (mediaModel!.supportsImageInput) out.add('Image Input');
    if (mediaModel!.supportsAudioInput) out.add('Audio Input');
    if (mediaModel!.supportsVideoInput) out.add('Video Input');
    return out;
  }

  List<_InfoItem> get _infoItems {
    if (isChat) {
      return [
        _InfoItem('Provider', model!.provider),
        _InfoItem('Model ID', model!.id),
        _InfoItem('Type', 'Chat'),
        _InfoItem('Popularity', model!.popular ? 'Popular' : 'Standard'),
      ];
    }

    return [
      _InfoItem('Provider', mediaModel!.provider),
      _InfoItem('Model ID', mediaModel!.id),
      _InfoItem('Category', mediaModel!.categoryLabel),
      _InfoItem('Editing Support', mediaModel!.supportsEditing ? 'Yes' : 'No'),
    ];
  }

  List<String> get _strengths {
    if (isChat) {
      final s = <String>[];
      if (model!.official) s.add('Official curated chat model');
      if (model!.popular) s.add('Popular choice for everyday conversations');
      s.add('Works inside your normal GPMai chat workflow');
      s.add('Good for general prompting, writing, and brainstorming');
      return s;
    }

    final s = <String>[];
    switch (mediaModel!.category) {
      case MediaCategory.image:
        s.add('Made for image generation workflows');
        if (mediaModel!.supportsEditing) {
          s.add('Supports editing and transformation use cases');
        }
        if (mediaModel!.supportsImageInput) {
          s.add('Can work with image-based input');
        }
        break;
      case MediaCategory.audio:
        s.add('Designed for audio generation or voice workflows');
        if (mediaModel!.supportsEditing) {
          s.add('Can support editing-oriented audio tasks');
        }
        break;
      case MediaCategory.video:
        s.add('Built for video generation workflows');
        if (mediaModel!.supportsImageInput) {
          s.add('Can use image input for image-to-video style tasks');
        }
        if (mediaModel!.supportsEditing) {
          s.add('Can support more advanced generation and edit flows');
        }
        break;
    }
    return s;
  }

  void _handlePrimaryAction() {
    if (isChat) {
      onStartChat?.call();
    } else {
      onGenerate?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF7F8FC);
    final card = isDark ? const Color(0xFF0D111A) : Colors.white;
    final border = isDark ? Colors.white10 : Colors.black12;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    final primary = Theme.of(context).colorScheme.primary;
    final brand = ProviderBranding.resolve(provider: _provider, modelId: isChat ? model!.id : mediaModel!.id, displayName: _title);
    final accent = brand.accent;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: brand.vividGradient(Theme.of(context).brightness)),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: brand.border(Theme.of(context).brightness)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ProviderBadge(label: brand.initials(_provider), color: accent),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$_provider • $_categoryLabel',
                              style: TextStyle(
                                color: subColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _chips.map((e) => _TagChip(text: e)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _description,
                    style: TextStyle(
                      color: isDark ? Colors.white.withOpacity(.84) : Colors.black87,
                      height: 1.45,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: brand.surface(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._infoItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InfoRow(label: item.label, value: item.value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: brand.surface(Theme.of(context).brightness),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why use this model',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._strengths.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BulletLine(text: s),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: Row(
            children: [
              if (isChat && onOpenHistory != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenHistory,
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('History'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      side: BorderSide(color: primary.withOpacity(.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: _handlePrimaryAction,
                  icon: Icon(_primaryActionIcon),
                  label: Text(_primaryActionLabel),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _providerColor(String provider) {
    switch (provider.trim().toLowerCase()) {
      case 'openai':
        return const Color(0xFFFF4FB1);
      case 'anthropic':
        return const Color(0xFFFF9F1C);
      case 'google':
        return const Color(0xFFFFD54A);
      case 'xai':
      case 'grok':
        return const Color(0xFFE53935);
      case 'qwen':
        return const Color(0xFF6BE4FF);
      case 'deepseek':
        return const Color(0xFF7FA8FF);
      case 'mistral':
      case 'mistralai':
        return const Color(0xFF7E57C2);
      case 'cohere':
        return const Color(0xFF8BFFB3);
      case 'minimax':
        return const Color(0xFF63E6BE);
      case 'tencent':
        return const Color(0xFF4DABF7);
      case 'prunaai':
        return const Color(0xFFFFB04D);
      default:
        return const Color(0xFF98A2B3);
    }
  }

  static String _providerInitials(String provider) {
    final parts = provider.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _ProviderBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ProviderBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.30), color.withOpacity(0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;

  const _TagChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : Colors.black12,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white.withOpacity(.92) : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dot = isDark ? Colors.white70 : Colors.black54;
    final textColor = isDark ? Colors.white.withOpacity(.84) : Colors.black87;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 8, color: dot),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _InfoItem {
  final String label;
  final String value;

  const _InfoItem(this.label, this.value);
}
