import 'package:flutter/material.dart';

import '../services/curated_models.dart';

class ModelCard extends StatelessWidget {
  final CuratedModel model;
  final VoidCallback? onTap;
  final bool compact;
  final bool showDescription;
  final EdgeInsetsGeometry? margin;

  const ModelCard({
    super.key,
    required this.model,
    this.onTap,
    this.compact = false,
    this.showDescription = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _providerColor(model.providerKey);
    final borderColor = Colors.white.withOpacity(0.08);

    return Container(
      margin: margin,
      child: Material(
        color: const Color(0xFF0D111A),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            width: compact ? 210 : double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProviderBadge(
                  label: _providerInitials(model.provider),
                  color: accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        model.provider,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (showDescription) ...[
                        const SizedBox(height: 8),
                        Text(
                          model.description,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            height: 1.35,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(text: model.official ? 'OFFICIAL' : 'MODEL'),
                          if (model.popular) const _Chip(text: 'POPULAR'),
                          if (model.supportsReasoning) const _Chip(text: 'REASONING'),
                          if (model.supportsCoding) const _Chip(text: 'CODING'),
                          if (model.supportsVision) const _Chip(text: 'VISION'),
                          if (model.supportsTools) const _Chip(text: 'TOOLS'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _providerColor(String provider) {
    switch (provider) {
      case 'openai':
        return const Color(0xFFFF4FB1);
      case 'anthropic':
        return const Color(0xFFFF8B5E);
      case 'google':
        return const Color(0xFFFFD54A);
      case 'deepseek':
        return const Color(0xFF7FA8FF);
      case 'meta':
        return const Color(0xFF8B7BFF);
      case 'mistral':
      case 'mistralai':
        return const Color(0xFFFFB04D);
      case 'xai':
      case 'x-ai':
        return const Color(0xFF7EF0C5);
      case 'qwen':
        return const Color(0xFF6BE4FF);
      case 'cohere':
        return const Color(0xFF8BFFB3);
      case 'amazon':
        return const Color(0xFFFFC266);
      case 'z ai':
      case 'z.ai':
      case 'z-ai':
        return const Color(0xFF97B1FF);
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

  const _ProviderBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.28),
            color.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.92),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}