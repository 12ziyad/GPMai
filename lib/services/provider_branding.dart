import 'package:flutter/material.dart';

class ProviderBranding {
  final String key;
  final String label;
  final Color accent;
  final Color secondary;
  final Color tertiary;

  const ProviderBranding({
    required this.key,
    required this.label,
    required this.accent,
    required this.secondary,
    required this.tertiary,
  });

  static ProviderBranding resolve({
    required String provider,
    String? modelId,
    String? displayName,
  }) {
    final p = provider.trim().toLowerCase();
    final id = (modelId ?? '').trim().toLowerCase();
    final name = (displayName ?? '').trim().toLowerCase();
    final hay = '$p $id $name';

    if (hay.contains('flux') || hay.contains('black-forest-labs')) {
      return const ProviderBranding(
        key: 'flux',
        label: 'Flux',
        accent: Color(0xFFBE72FF),
        secondary: Color(0xFF6B2AA6),
        tertiary: Color(0xFF23112F),
      );
    }
    if (hay.contains('recraft')) {
      return const ProviderBranding(
        key: 'recraft',
        label: 'Recraft',
        accent: Color(0xFF33D69F),
        secondary: Color(0xFF146B54),
        tertiary: Color(0xFF0F1F1A),
      );
    }
    if (hay.contains('ideogram')) {
      return const ProviderBranding(
        key: 'ideogram',
        label: 'Ideogram',
        accent: Color(0xFFFF6D9E),
        secondary: Color(0xFF8B2B56),
        tertiary: Color(0xFF26101A),
      );
    }
    if (hay.contains('seedream') || hay.contains('bytedance')) {
      return const ProviderBranding(
        key: 'seedream',
        label: 'Seedream',
        accent: Color(0xFFFF6A5E),
        secondary: Color(0xFF9E2F28),
        tertiary: Color(0xFF291110),
      );
    }
    if (hay.contains('qwen')) {
      return const ProviderBranding(
        key: 'qwen',
        label: 'Qwen',
        accent: Color(0xFF47D9FF),
        secondary: Color(0xFF16708E),
        tertiary: Color(0xFF0D1D24),
      );
    }
    if (hay.contains('minimax')) {
      return const ProviderBranding(
        key: 'minimax',
        label: 'MiniMax',
        accent: Color(0xFF29D17D),
        secondary: Color(0xFF127048),
        tertiary: Color(0xFF0D1D16),
      );
    }
    if (hay.contains('elevenlabs')) {
      return const ProviderBranding(
        key: 'elevenlabs',
        label: 'ElevenLabs',
        accent: Color(0xFFC88842),
        secondary: Color(0xFF74441A),
        tertiary: Color(0xFF24160B),
      );
    }
    if (hay.contains('stable-audio') || hay.contains('stability-ai') || hay.contains('stability ai')) {
      return const ProviderBranding(
        key: 'stability',
        label: 'Stability',
        accent: Color(0xFF9C7BFF),
        secondary: Color(0xFF5F3AB7),
        tertiary: Color(0xFF18112B),
      );
    }
    if (hay.contains('kling') || hay.contains('kwaivgi')) {
      return const ProviderBranding(
        key: 'kling',
        label: 'Kling',
        accent: Color(0xFFD06AFF),
        secondary: Color(0xFF772B9D),
        tertiary: Color(0xFF231028),
      );
    }
    if (hay.contains('wan-') || hay.contains('wan video')) {
      return const ProviderBranding(
        key: 'wan',
        label: 'Wan',
        accent: Color(0xFF33C7C9),
        secondary: Color(0xFF167679),
        tertiary: Color(0xFF0D1D1F),
      );
    }
    if (hay.contains('ltx') || hay.contains('lightricks')) {
      return const ProviderBranding(
        key: 'ltx',
        label: 'LTX',
        accent: Color(0xFF8DDB54),
        secondary: Color(0xFF4F7E21),
        tertiary: Color(0xFF16210E),
      );
    }

    switch (p) {
      case 'openai':
        return const ProviderBranding(
          key: 'openai',
          label: 'OpenAI',
          accent: Color(0xFFFF4FA6),
          secondary: Color(0xFF9E2B6D),
          tertiary: Color(0xFF280F1E),
        );
      case 'anthropic':
        return const ProviderBranding(
          key: 'anthropic',
          label: 'Anthropic',
          accent: Color(0xFFD49074),
          secondary: Color(0xFF7A4333),
          tertiary: Color(0xFF241511),
        );
      case 'google':
        return const ProviderBranding(
          key: 'google',
          label: 'Google',
          accent: Color(0xFF4B8EFF),
          secondary: Color(0xFF1D4DA4),
          tertiary: Color(0xFF101829),
        );
      case 'deepseek':
        return const ProviderBranding(
          key: 'deepseek',
          label: 'DeepSeek',
          accent: Color(0xFF1DB9A8),
          secondary: Color(0xFF136C63),
          tertiary: Color(0xFF0D1D1A),
        );
      case 'meta':
      case 'meta-llama':
        return const ProviderBranding(
          key: 'meta',
          label: 'Meta',
          accent: Color(0xFF6E7CFF),
          secondary: Color(0xFF3345B2),
          tertiary: Color(0xFF13172A),
        );
      case 'mistral':
      case 'mistralai':
        return const ProviderBranding(
          key: 'mistral',
          label: 'Mistral',
          accent: Color(0xFF8B67FF),
          secondary: Color(0xFF4A2CA7),
          tertiary: Color(0xFF171127),
        );
      case 'xai':
      case 'grok':
        return const ProviderBranding(
          key: 'xai',
          label: 'xAI',
          accent: Color(0xFFE24B4B),
          secondary: Color(0xFF8E2020),
          tertiary: Color(0xFF251010),
        );
      case 'cohere':
        return const ProviderBranding(
          key: 'cohere',
          label: 'Cohere',
          accent: Color(0xFF53D0A3),
          secondary: Color(0xFF1C7A5A),
          tertiary: Color(0xFF102119),
        );
      case 'replicate':
        return const ProviderBranding(
          key: 'replicate',
          label: 'Replicate',
          accent: Color(0xFF8F69FF),
          secondary: Color(0xFF5131B4),
          tertiary: Color(0xFF161229),
        );
      default:
        return const ProviderBranding(
          key: 'default',
          label: 'GPMai',
          accent: Color(0xFF7A8BA5),
          secondary: Color(0xFF344455),
          tertiary: Color(0xFF151A21),
        );
    }
  }

  List<Color> cardGradient(Brightness brightness) {
    if (brightness == Brightness.light) {
      return <Color>[
        Color.alphaBlend(accent.withOpacity(.28), const Color(0xFFF8FAFF)),
        Color.alphaBlend(secondary.withOpacity(.22), const Color(0xFFF2F4F9)),
        Color.alphaBlend(tertiary.withOpacity(.16), const Color(0xFFEAEFF6)),
      ];
    }
    return <Color>[
      Color.alphaBlend(accent.withOpacity(.42), const Color(0xFF151824)),
      Color.alphaBlend(secondary.withOpacity(.48), const Color(0xFF10131B)),
      const Color(0xFF090B11),
    ];
  }

  List<Color> vividGradient(Brightness brightness) {
    if (brightness == Brightness.light) {
      return <Color>[
        Color.alphaBlend(accent.withOpacity(.34), const Color(0xFFFBFCFF)),
        Color.alphaBlend(accent.withOpacity(.16), const Color(0xFFF3F6FB)),
        Color.alphaBlend(secondary.withOpacity(.18), const Color(0xFFEFF3F8)),
      ];
    }
    return <Color>[
      Color.alphaBlend(accent.withOpacity(.52), const Color(0xFF151925)),
      Color.alphaBlend(secondary.withOpacity(.52), const Color(0xFF10131B)),
      const Color(0xFF090B11),
    ];
  }

  Color surface(Brightness brightness) {
    return brightness == Brightness.light
        ? Color.alphaBlend(secondary.withOpacity(.08), const Color(0xFFF6F8FC))
        : Color.alphaBlend(accent.withOpacity(.08), const Color(0xFF0F131A));
  }

  Color iconFill(Brightness brightness) {
    return brightness == Brightness.light
        ? accent.withOpacity(.16)
        : accent.withOpacity(.18);
  }

  Color border(Brightness brightness) {
    return brightness == Brightness.light
        ? accent.withOpacity(.40)
        : accent.withOpacity(.56);
  }

  Color mutedText(Brightness brightness) {
    return brightness == Brightness.light ? Colors.black54 : Colors.white70;
  }

  Color responseBorder(Brightness brightness) {
    return brightness == Brightness.light
        ? accent.withOpacity(.52)
        : accent.withOpacity(.68);
  }

  Color responseSurface(Brightness brightness) {
    return brightness == Brightness.light
        ? Color.alphaBlend(accent.withOpacity(.08), const Color(0xFFF9FBFF))
        : Color.alphaBlend(accent.withOpacity(.08), const Color(0xFF141922));
  }

  String initials([String? provider]) {
    final source = (provider ?? label).trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
