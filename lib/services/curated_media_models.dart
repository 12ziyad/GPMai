enum MediaCategory {
  image,
  video,
  audio,
}

class CuratedMediaModel {
  final String id;
  final String name;
  final String provider;
  final MediaCategory category;
  final String description;
  final List<String> tags;
  final bool featured;
  final String? badge;
  final bool supportsEdit;
  final bool supportsReferenceImage;
  final bool supportsImageInput;
  final bool supportsAudioInput;
  final bool isOfficial;

  const CuratedMediaModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.category,
    required this.description,
    this.tags = const [],
    this.featured = false,
    this.badge,
    this.supportsEdit = false,
    this.supportsReferenceImage = false,
    this.supportsImageInput = false,
    this.supportsAudioInput = false,
    this.isOfficial = false,
  });

  bool get isFeatured => featured;

  String get categoryKey {
    switch (category) {
      case MediaCategory.image:
        return 'image';
      case MediaCategory.video:
        return 'video';
      case MediaCategory.audio:
        return 'audio';
    }
  }

  String get categoryLabel {
    switch (category) {
      case MediaCategory.image:
        return 'Image';
      case MediaCategory.video:
        return 'Video';
      case MediaCategory.audio:
        return 'Audio';
    }
  }

  // compatibility helpers for older screens
  bool get supportsEditing => supportsEdit;
  bool get supportsVideoInput => category == MediaCategory.video;


  bool get supportsImageUpload =>
      supportsImageInput || supportsEdit || supportsReferenceImage;

  String get providerBadge {
    final slug = id.contains('/') ? id.split('/').first.trim().toLowerCase() : provider.trim().toLowerCase();
    const map = {
      'google': 'Google',
      'xai': 'Grok',
      'qwen': 'Qwen',
      'minimax': 'MiniMax',
      'ideogram-ai': 'Ideogram',
      'black-forest-labs': 'BFL',
      'recraft-ai': 'Recraft',
      'bytedance': 'ByteDance',
      'stability-ai': 'Stability',
      'elevenlabs': 'ElevenLabs',
      'lightricks': 'Lightricks',
      'kwaivgi': 'Kling',
      'wan-video': 'Wan',
      'wavespeedai': 'WaveSpeed',
      'luma': 'Luma',
      'pixverse-ai': 'PixVerse',
      'bria': 'Bria',
      'leonardoai': 'Leonardo',
      'lucataco': 'LucaTaco',
      'prunaai': 'Pruna',
      'republiclabs': 'Republic',
    };
    return map[slug] ?? provider;
  }

  List<String> get capabilityBadges {
    switch (category) {
      case MediaCategory.image:
        if (supportsEdit) return const ['Edit'];
        if (supportsReferenceImage) return const ['Reference'];
        if (supportsImageInput) return const ['Image Input'];
        return const ['Text to Image'];
      case MediaCategory.video:
        if (supportsImageInput) return const ['Image to Video'];
        return const ['Text to Video'];
      case MediaCategory.audio:
        if (supportsAudioInput) return const ['Reference Audio'];
        return const ['Audio'];
    }
  }

}

typedef MediaModel = CuratedMediaModel;

class CuratedMediaCatalog {
  // =========================
  // IMAGE MODELS (30+)
  // =========================
  static const List<CuratedMediaModel> imageModels = [
    CuratedMediaModel(
      id: 'google/imagen-3',
      name: 'Imagen 3',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Reliable Imagen generation with rich lighting and polished outputs.',
      tags: ['quality', 'classic', 'general'],
      badge: 'GOOGLE',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'google/imagen-3-fast',
      name: 'Imagen 3 Fast',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Faster and lighter Imagen 3 variant for budget-friendly creation.',
      tags: ['fast', 'budget', 'general'],
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'google/nano-banana',
      name: 'Nano Banana',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Google image editing model designed for guided transformations.',
      tags: ['edit', 'google', 'creative'],
      featured: true,
      badge: 'EDIT',
      supportsEdit: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'black-forest-labs/flux-schnell',
      name: 'FLUX Schnell',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Very fast FLUX model for ideation and rapid experiments.',
      tags: ['fast', 'ideation', 'budget'],
      featured: true,
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'black-forest-labs/flux-pro',
      name: 'FLUX Pro',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Production-grade FLUX image generation with strong prompt accuracy.',
      tags: ['quality', 'premium', 'general'],
      featured: true,
      badge: 'PRO',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'black-forest-labs/flux-kontext-pro',
      name: 'FLUX Kontext Pro',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'High-end image editing and reference-guided transformation model.',
      tags: ['edit', 'reference', 'guided'],
      featured: true,
      badge: 'EDIT',
      supportsEdit: true,
      supportsReferenceImage: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'recraft-ai/recraft-v4',
      name: 'Recraft V4',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Great for design-led visuals, text rendering, and branding assets.',
      tags: ['design', 'text', 'branding'],
      featured: true,
      badge: 'DESIGN',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'recraft-ai/recraft-v4-pro',
      name: 'Recraft V4 Pro',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Higher-end Recraft model for sharper design outputs and detail.',
      tags: ['design', 'premium', 'high-res'],
      badge: 'PRO',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'recraft-ai/recraft-v4-svg',
      name: 'Recraft V4 SVG',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Vector-oriented design model for logos, icons, and scalable assets.',
      tags: ['svg', 'vector', 'logo'],
      badge: 'SVG',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'recraft-ai/recraft-v4-pro-svg',
      name: 'Recraft V4 Pro SVG',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Premium SVG-style output for scalable branding work.',
      tags: ['svg', 'vector', 'premium'],
      badge: 'SVG',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'recraft-ai/recraft-v3',
      name: 'Recraft V3',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Strong all-rounder for styled visuals and text-heavy assets.',
      tags: ['design', 'creative', 'text'],
      badge: 'DESIGN',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'recraft-ai/recraft-v3-svg',
      name: 'Recraft V3 SVG',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Vector-friendly Recraft V3 variant for icon and logo use cases.',
      tags: ['svg', 'logo', 'vector'],
      badge: 'SVG',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'ideogram-ai/ideogram-v3-turbo',
      name: 'Ideogram V3 Turbo',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Fast Ideogram model with strong text rendering and clean layouts.',
      tags: ['text', 'poster', 'fast'],
      featured: true,
      badge: 'TEXT',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'ideogram-ai/ideogram-v3-quality',
      name: 'Ideogram V3 Quality',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Higher-quality Ideogram tier for polished text-heavy visuals.',
      tags: ['text', 'quality', 'design'],
      badge: 'QUALITY',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'ideogram-ai/ideogram-v3-balanced',
      name: 'Ideogram V3 Balanced',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Balanced speed and quality for posters, social graphics, and banners.',
      tags: ['balanced', 'text', 'general'],
      badge: 'BALANCED',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'ideogram-ai/ideogram-v2',
      name: 'Ideogram V2',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Strong prompt understanding and text rendering with editing support.',
      tags: ['text', 'edit', 'creative'],
      badge: 'TEXT',
      supportsEdit: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'ideogram-ai/ideogram-v2-turbo',
      name: 'Ideogram V2 Turbo',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Faster Ideogram V2 variant for quick poster and brand concept work.',
      tags: ['fast', 'text', 'poster'],
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'ideogram-ai/ideogram-v2a',
      name: 'Ideogram V2A',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Lighter Ideogram model for efficient text-led image generation.',
      tags: ['text', 'budget', 'general'],
      badge: 'BUDGET',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'ideogram-ai/ideogram-v2a-turbo',
      name: 'Ideogram V2A Turbo',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Turbo text-image model built for speed-first creative tasks.',
      tags: ['turbo', 'fast', 'creative'],
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'bytedance/seedream-5-lite',
      name: 'Seedream 5 Lite',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Modern image model with reasoning-led prompt following and editing.',
      tags: ['reasoning', 'edit', 'creative'],
      badge: 'MODERN',
      supportsEdit: true,
      supportsReferenceImage: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'bytedance/seedream-4.5',
      name: 'Seedream 4.5',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Strong text-guided editing and visual transformation model.',
      tags: ['edit', 'guided', 'quality'],
      badge: 'EDIT',
      supportsEdit: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'stability-ai/stable-diffusion-3.5-large',
      name: 'SD 3.5 Large',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'High-detail diffusion model with strong style flexibility.',
      tags: ['diffusion', 'high-res', 'classic'],
      badge: 'DIFFUSION',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'stability-ai/stable-diffusion-3.5-large-turbo',
      name: 'SD 3.5 Large Turbo',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Faster SD 3.5 variant for speed and lower inference cost.',
      tags: ['fast', 'diffusion', 'general'],
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'stability-ai/stable-diffusion-3.5-medium',
      name: 'SD 3.5 Medium',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Smaller SD 3.5 model for lighter and cheaper generation.',
      tags: ['budget', 'diffusion', 'general'],
      badge: 'BUDGET',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'qwen/qwen-image-2',
      name: 'Qwen Image 2',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Next-gen Qwen image model with strong text and editing abilities.',
      tags: ['edit', 'text', 'modern'],
      badge: 'QWEN',
      supportsEdit: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'xai/grok-imagine-image',
      name: 'Grok Imagine Image',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Modern general-purpose xAI image model for broad creative prompts.',
      tags: ['general', 'modern', 'quality'],
      badge: 'XAI',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'minimax/image-01',
      name: 'MiniMax Image 01',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Image generation with stronger character and reference handling.',
      tags: ['reference', 'character', 'creative'],
      badge: 'REFERENCE',
      supportsReferenceImage: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'luma/photon-flash',
      name: 'Photon Flash',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Fast Luma image model prioritizing turnaround and iteration.',
      tags: ['fast', 'creative', 'general'],
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'leonardoai/lucid-origin',
      name: 'Lucid Origin',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Artistic and high-quality visual generation with vivid style.',
      tags: ['art', 'creative', 'quality'],
      badge: 'ART',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'prunaai/p-image',
      name: 'P-Image',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Ultra-fast production image model for scalable use cases.',
      tags: ['fast', 'production', 'budget'],
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'prunaai/z-image-turbo',
      name: 'Z-Image Turbo',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Super-fast text-to-image model for quick iteration.',
      tags: ['turbo', 'fast', 'budget'],
      badge: 'TURBO',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'prunaai/hidream-l1-fast',
      name: 'HiDream L1 Fast',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Optimized fast image model for lightweight scalable generation.',
      tags: ['fast', 'general', 'production'],
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'bria/fibo',
      name: 'Bria Fibo',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Enterprise-friendly image generation focused on controlled outputs.',
      tags: ['enterprise', 'licensed', 'control'],
      badge: 'ENTERPRISE',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'lucataco/ssd-1b',
      name: 'SSD 1B',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Smaller SDXL-style model for fast budget generation.',
      tags: ['budget', 'fast', 'sdxl'],
      badge: 'BUDGET',
      isOfficial: false,
    ),
    CuratedMediaModel(
      id: 'lucataco/realistic-vision-v5.1',
      name: 'Realistic Vision 5.1',
      provider: 'Replicate',
      category: MediaCategory.image,
      description: 'Popular community model focused on realism and photo-like outputs.',
      tags: ['realistic', 'photo', 'community'],
      badge: 'REALISM',
      isOfficial: false,
    ),
  ];

  // =========================
  // VIDEO MODELS (15+)
  // =========================
  static const List<CuratedMediaModel> videoModels = [
    CuratedMediaModel(
      id: 'google/veo-3-fast',
      name: 'Veo 3 Fast',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Fast Google text-to-video with strong motion and polished output.',
      tags: ['flagship', 'fast', 'audio'],
      featured: true,
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'google/veo-3',
      name: 'Veo 3',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Google flagship video generation with rich motion and premium visuals.',
      tags: ['flagship', 'premium', 'audio'],
      featured: true,
      badge: 'PRO',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'google/veo-3.1-fast',
      name: 'Veo 3.1 Fast',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Improved fast Veo tier with better quality-speed balance.',
      tags: ['fast', 'audio', 'modern'],
      featured: true,
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'google/veo-3.1',
      name: 'Veo 3.1',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Premium Veo generation with stronger reference image support.',
      tags: ['premium', 'audio', 'reference'],
      featured: true,
      badge: 'PRO',
      supportsImageInput: true,
      supportsReferenceImage: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'google/veo-2',
      name: 'Veo 2',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Older high-quality Google video model still useful for premium motion.',
      tags: ['google', 'quality', 'classic'],
      badge: 'GOOGLE',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'lightricks/ltx-2.3-fast',
      name: 'LTX 2.3 Fast',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Lightning-fast video generation with camera-friendly controls.',
      tags: ['fast', 'camera', 'audio'],
      featured: true,
      badge: 'FAST',
      supportsAudioInput: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'lightricks/ltx-2.3-pro',
      name: 'LTX 2.3 Pro',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'High-fidelity video creation for premium cinematic outputs.',
      tags: ['premium', 'audio', 'image-to-video'],
      featured: true,
      badge: 'PRO',
      supportsAudioInput: true,
      supportsImageInput: true,
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'pixverse-ai/pixverse-v5',
      name: 'PixVerse V5',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Balanced quality and style for short-form social and cinematic clips.',
      tags: ['balanced', 'stylized', 'short-form'],
      featured: true,
      badge: 'BALANCED',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'kwaivgi/kling-v2.6',
      name: 'Kling 2.6',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Top-tier image-to-video with cinematic movement.',
      tags: ['cinematic', 'audio', 'image-to-video'],
      supportsImageInput: true,
      badge: 'CINEMATIC',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'kwaivgi/kling-v1.6-standard',
      name: 'Kling 1.6 Standard',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Reliable 5s and 10s generation with stable prompt behavior.',
      tags: ['reliable', '720p', 'classic'],
      badge: 'STANDARD',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'kwaivgi/kling-v2.1',
      name: 'Kling 2.1',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Image-to-video Kling variant with stronger visual fidelity.',
      tags: ['image-to-video', '1080p', 'kling'],
      supportsImageInput: true,
      badge: 'I2V',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'wan-video/wan-2.5-t2v',
      name: 'Wan 2.5 T2V',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Open text-to-video option for affordable scalable generation.',
      tags: ['text-to-video', 'budget', 'open'],
      badge: 'OPEN',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'wan-video/wan-2.5-i2v',
      name: 'Wan 2.5 I2V',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Wan image-to-video with broader motion support.',
      tags: ['image-to-video', 'audio', 'open'],
      supportsImageInput: true,
      badge: 'I2V',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'wan-video/wan-2.5-i2v-fast',
      name: 'Wan 2.5 I2V Fast',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Faster Wan image-to-video option optimized for speed.',
      tags: ['fast', 'image-to-video', 'budget'],
      supportsImageInput: true,
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'wavespeedai/wan-2.1-t2v-480p',
      name: 'Wan 2.1 T2V 480p',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Cheap and lightweight text-to-video for quick concepts.',
      tags: ['480p', 'fast', 'budget'],
      badge: 'BUDGET',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'luma/ray-2-540p',
      name: 'Ray 2 540p',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Luma Ray 2 at 540p for lighter-cost video generation.',
      tags: ['540p', 'balanced', 'luma'],
      badge: 'BALANCED',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'luma/ray-2-720p',
      name: 'Ray 2 720p',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Sharper Luma Ray 2 output for better premium-looking clips.',
      tags: ['720p', 'quality', 'luma'],
      badge: 'QUALITY',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'minimax/video-01',
      name: 'MiniMax Video 01',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Modern general-purpose video model for broad creative prompts.',
      tags: ['modern', 'general', 'video'],
      badge: 'MINIMAX',
      isOfficial: false,
    ),
    CuratedMediaModel(
      id: 'luma/reframe-video',
      name: 'Reframe Video',
      provider: 'Replicate',
      category: MediaCategory.video,
      description: 'Useful utility model for reframing existing video outputs.',
      tags: ['edit', 'reframe', 'utility'],
      badge: 'UTILITY',
      supportsEdit: true,
      isOfficial: false,
    ),
  ];

  // =========================
  // AUDIO MODELS (15+)
  // =========================
  static const List<CuratedMediaModel> audioModels = [
    CuratedMediaModel(
      id: 'qwen/qwen3-tts',
      name: 'Qwen3 TTS',
      provider: 'Replicate',
      category: MediaCategory.audio,
      description: 'Text-to-speech with exact speaker choices like Aiden and Serena.',
      tags: ['tts', 'speaker', 'qwen'],
      featured: true,
      badge: 'PRO',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'elevenlabs/turbo-v2.5',
      name: 'ElevenLabs Turbo v2.5',
      provider: 'Replicate',
      category: MediaCategory.audio,
      description: 'Fast speech generation with exact ElevenLabs voices.',
      tags: ['tts', 'voice', 'elevenlabs'],
      featured: true,
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'elevenlabs/flash-v2.5',
      name: 'ElevenLabs Flash v2.5',
      provider: 'Replicate',
      category: MediaCategory.audio,
      description: 'Fast speech generation using exact voice names.',
      tags: ['tts', 'voice', 'speech'],
      featured: true,
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'minimax/speech-2.8-turbo',
      name: 'MiniMax Speech 2.8 Turbo',
      provider: 'Replicate',
      category: MediaCategory.audio,
      description: 'Fast speech model with simple voice style controls.',
      tags: ['tts', 'speech', 'style'],
      featured: true,
      badge: 'FAST',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'minimax/speech-2.8-hd',
      name: 'MiniMax Speech 2.8 HD',
      provider: 'Replicate',
      category: MediaCategory.audio,
      description: 'Higher-quality speech model with simple voice style controls.',
      tags: ['tts', 'speech', 'hd'],
      featured: true,
      badge: 'HD',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'stability-ai/stable-audio-2.5',
      name: 'Stable Audio 2.5',
      provider: 'Replicate',
      category: MediaCategory.audio,
      description: 'Prompt-based music and audio generation.',
      tags: ['music', 'audio', 'generation'],
      featured: true,
      badge: 'MUSIC',
      isOfficial: true,
    ),
    CuratedMediaModel(
      id: 'minimax/music-1.5',
      name: 'Music 1.5',
      provider: 'Replicate',
      category: MediaCategory.audio,
      description: 'Prompt-based song and music generation.',
      tags: ['music', 'song', 'generation'],
      featured: true,
      badge: 'SONG',
      isOfficial: true,
    ),
  ];

  static List<CuratedMediaModel> get featuredImageModels =>
      imageModels.where((m) => m.isFeatured).toList(growable: false);

  static List<CuratedMediaModel> get featuredVideoModels =>
      videoModels.where((m) => m.isFeatured).toList(growable: false);

  static List<CuratedMediaModel> get featuredAudioModels =>
      audioModels.where((m) => m.isFeatured).toList(growable: false);

  static List<CuratedMediaModel> get allModels => [
        ...imageModels,
        ...videoModels,
        ...audioModels,
      ];

  static List<CuratedMediaModel> byCategory(MediaCategory category) {
    switch (category) {
      case MediaCategory.image:
        return imageModels;
      case MediaCategory.video:
        return videoModels;
      case MediaCategory.audio:
        return audioModels;
    }
  }

  static CuratedMediaModel? findById(String id) {
    final key = id.trim().toLowerCase();
    for (final model in allModels) {
      if (model.id.trim().toLowerCase() == key) return model;
    }
    return null;
  }
}

const List<CuratedMediaModel> imageModels = CuratedMediaCatalog.imageModels;
const List<CuratedMediaModel> videoModels = CuratedMediaCatalog.videoModels;
const List<CuratedMediaModel> audioModels = CuratedMediaCatalog.audioModels;


