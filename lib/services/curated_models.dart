enum ExploreFilter {
  official,
  popular,
}

class CuratedModel {
  final String key;
  final String displayName;
  final String provider;
  final String preferredId;
  final List<String> aliases;
  final String description;
  final bool official;
  final bool popular;
  final bool supportsVision;
  final bool supportsTools;
  final bool supportsReasoning;
  final bool supportsCoding;
  final int rank;

  const CuratedModel({
    required this.key,
    required this.displayName,
    required this.provider,
    required this.preferredId,
    this.aliases = const [],
    required this.description,
    this.official = true,
    this.popular = false,
    this.supportsVision = false,
    this.supportsTools = false,
    this.supportsReasoning = false,
    this.supportsCoding = false,
    this.rank = 0,
  });

  String get id => preferredId;

  String get providerKey => _normalize(provider);

  String get subtitle {
    if (supportsReasoning) return 'Reasoning';
    if (supportsCoding) return 'Coding';
    if (supportsVision) return 'Vision';
    if (supportsTools) return 'Tools';
    return provider;
  }

  String get normalizedDisplayName => _normalize(displayName);

  List<String> get normalizedAliases => aliases.map(_normalize).toList();

  CuratedModel copyWithResolvedId(String resolvedId) {
    return CuratedModel(
      key: key,
      displayName: displayName,
      provider: provider,
      preferredId: resolvedId,
      aliases: aliases,
      description: description,
      official: official,
      popular: popular,
      supportsVision: supportsVision,
      supportsTools: supportsTools,
      supportsReasoning: supportsReasoning,
      supportsCoding: supportsCoding,
      rank: rank,
    );
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

const List<CuratedModel> curatedOfficialModels = [
  // OpenAI
  CuratedModel(
    key: 'openai-gpt52',
    displayName: 'GPT-5.2',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-5.2',
    aliases: ['gpt 5.2', 'openai gpt 5.2'],
    description: 'Latest flagship OpenAI model for premium tasks.',
    popular: true,
    supportsReasoning: true,
    supportsCoding: true,
    rank: 100,
  ),
  CuratedModel(
    key: 'openai-gpt51',
    displayName: 'GPT-5.1',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-5.1',
    aliases: ['gpt 5.1', 'openai gpt 5.1'],
    description: 'Balanced flagship OpenAI model for daily high-end use.',
    popular: true,
    supportsReasoning: true,
    supportsCoding: true,
    rank: 98,
  ),
  CuratedModel(
    key: 'openai-gpt51-mini',
    displayName: 'GPT-5.1 Mini',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-5.1-mini',
    aliases: ['gpt 5.1 mini', 'openai gpt 5.1 mini'],
    description: 'Smaller GPT-5.1 variant with strong speed and value.',
    popular: true,
    supportsCoding: true,
    rank: 96,
  ),
  CuratedModel(
    key: 'openai-gpt51-codex-mini',
    displayName: 'GPT-5.1 Codex Mini',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-5.1-codex-mini',
    aliases: ['gpt 5.1 codex mini'],
    description: 'Compact OpenAI coding model.',
    popular: true,
    supportsCoding: true,
    supportsReasoning: true,
    rank: 91,
  ),
  CuratedModel(
    key: 'openai-gpt5-mini',
    displayName: 'GPT-5 Mini',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-5-mini',
    aliases: ['gpt 5 mini'],
    description: 'Fast GPT-5 family model for chat and coding.',
    popular: true,
    supportsCoding: true,
    rank: 95,
  ),
  CuratedModel(
    key: 'openai-gpt5-nano',
    displayName: 'GPT-5 Nano',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-5-nano',
    aliases: ['gpt 5 nano'],
    description: 'Ultra-fast lightweight GPT-5 model.',
    rank: 70,
  ),
  CuratedModel(
    key: 'openai-gpt41-mini',
    displayName: 'GPT-4.1 Mini',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-4.1-mini',
    aliases: ['gpt 4.1 mini'],
    description: 'Very strong low-cost OpenAI model.',
    popular: true,
    supportsCoding: true,
    rank: 93,
  ),
  CuratedModel(
    key: 'openai-gpt41-nano',
    displayName: 'GPT-4.1 Nano',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-4.1-nano',
    aliases: ['gpt 4.1 nano'],
    description: 'Small and cheap OpenAI model for simple requests.',
    rank: 68,
  ),
  CuratedModel(
    key: 'openai-gpt4o-mini',
    displayName: 'GPT-4o Mini',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-4o-mini',
    aliases: ['gpt 4o mini'],
    description: 'Popular low-cost OpenAI multimodal model.',
    popular: true,
    supportsVision: true,
    rank: 92,
  ),
  CuratedModel(
    key: 'openai-gpt4o-mini-search-preview',
    displayName: 'GPT-4o Mini Search Preview',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-4o-mini-search-preview',
    aliases: ['gpt 4o mini search preview'],
    description: 'Search-oriented GPT-4o Mini variant.',
    supportsTools: true,
    rank: 66,
  ),
  CuratedModel(
    key: 'openai-gpt45-preview',
    displayName: 'GPT-4.5 Preview',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-4.5-preview',
    aliases: ['gpt 4.5 preview'],
    description: 'Preview flagship-style OpenAI model.',
    supportsReasoning: true,
    rank: 74,
  ),
  CuratedModel(
    key: 'openai-o1-mini',
    displayName: 'o1-mini',
    provider: 'OpenAI',
    preferredId: 'openai/o1-mini',
    aliases: ['o1 mini'],
    description: 'Compact OpenAI reasoning model.',
    popular: true,
    supportsReasoning: true,
    supportsCoding: true,
    rank: 88,
  ),
  CuratedModel(
    key: 'openai-o1-preview',
    displayName: 'o1-preview',
    provider: 'OpenAI',
    preferredId: 'openai/o1-preview',
    aliases: ['o1 preview'],
    description: 'Preview reasoning model from OpenAI.',
    popular: true,
    supportsReasoning: true,
    rank: 84,
  ),
  CuratedModel(
    key: 'openai-codex-mini',
    displayName: 'Codex Mini',
    provider: 'OpenAI',
    preferredId: 'openai/codex-mini',
    aliases: ['codex mini'],
    description: 'Compact OpenAI coding assistant model.',
    popular: true,
    supportsCoding: true,
    rank: 85,
  ),
  CuratedModel(
    key: 'openai-gpt35-turbo',
    displayName: 'GPT-3.5 Turbo',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-3.5-turbo',
    aliases: ['gpt 3.5 turbo'],
    description: 'Classic OpenAI low-cost model.',
    rank: 60,
  ),
  CuratedModel(
    key: 'openai-chatgpt4o',
    displayName: 'ChatGPT-4o',
    provider: 'OpenAI',
    preferredId: 'openai/chatgpt-4o',
    aliases: ['chatgpt 4o'],
    description: 'ChatGPT-tuned 4o-style model.',
    supportsVision: true,
    rank: 62,
  ),
  CuratedModel(
    key: 'openai-gpt4-vision',
    displayName: 'GPT-4 Vision',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-4-vision-preview',
    aliases: ['gpt 4 vision'],
    description: 'Vision-enabled GPT model.',
    supportsVision: true,
    rank: 58,
  ),
  CuratedModel(
    key: 'openai-gpt-oss-120b',
    displayName: 'gpt-oss-120b',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-oss-120b',
    aliases: ['gpt oss 120b'],
    description: 'Large open-weight OpenAI model with strong value.',
    popular: true,
    supportsCoding: true,
    rank: 78,
  ),
  CuratedModel(
    key: 'openai-gpt-oss-20b',
    displayName: 'gpt-oss-20b',
    provider: 'OpenAI',
    preferredId: 'openai/gpt-oss-20b',
    aliases: ['gpt oss 20b'],
    description: 'Smaller open-weight OpenAI model.',
    rank: 56,
  ),

  // Anthropic
  CuratedModel(
    key: 'anthropic-claude-opus-46',
    displayName: 'Claude Opus 4.6',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-opus-4.6',
    aliases: ['claude opus 4.6'],
    description: 'Top-tier Claude for premium reasoning and writing.',
    popular: true,
    supportsReasoning: true,
    supportsCoding: true,
    rank: 99,
  ),
  CuratedModel(
    key: 'anthropic-claude-sonnet-46',
    displayName: 'Claude Sonnet 4.6',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-sonnet-4.6',
    aliases: ['claude sonnet 4.6'],
    description: 'Fast premium Claude with huge context.',
    popular: true,
    supportsReasoning: true,
    supportsCoding: true,
    rank: 97,
  ),
  CuratedModel(
    key: 'anthropic-claude-opus-45',
    displayName: 'Claude Opus 4.5',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-opus-4.5',
    aliases: ['claude opus 4.5'],
    description: 'High-end Claude model for large-context reasoning.',
    supportsReasoning: true,
    rank: 83,
  ),
  CuratedModel(
    key: 'anthropic-claude-sonnet-45',
    displayName: 'Claude Sonnet 4.5',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-sonnet-4.5',
    aliases: ['claude sonnet 4.5'],
    description: 'Balanced premium Claude for everyday serious work.',
    popular: true,
    supportsCoding: true,
    rank: 90,
  ),
  CuratedModel(
    key: 'anthropic-claude-sonnet-4',
    displayName: 'Claude Sonnet 4',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-sonnet-4',
    aliases: ['claude sonnet 4'],
    description: 'Stable Sonnet model for professional tasks.',
    rank: 72,
  ),
  CuratedModel(
    key: 'anthropic-claude-37-sonnet',
    displayName: 'Claude 3.7 Sonnet',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-3.7-sonnet',
    aliases: ['claude 3.7 sonnet'],
    description: 'Popular Claude reasoning/coding model.',
    popular: true,
    supportsReasoning: true,
    supportsCoding: true,
    rank: 87,
  ),
  CuratedModel(
    key: 'anthropic-claude35-sonnet',
    displayName: 'Claude 3.5 Sonnet',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-3.5-sonnet',
    aliases: ['claude 3.5 sonnet'],
    description: 'Widely used Claude model for writing and coding.',
    popular: true,
    supportsCoding: true,
    rank: 86,
  ),
  CuratedModel(
    key: 'anthropic-claude-haiku-45',
    displayName: 'Claude Haiku 4.5',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-haiku-4.5',
    aliases: ['claude haiku 4.5'],
    description: 'Fast Claude model for lighter tasks.',
    popular: true,
    rank: 76,
  ),
  CuratedModel(
    key: 'anthropic-claude35-haiku',
    displayName: 'Claude 3.5 Haiku',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-3.5-haiku',
    aliases: ['claude 3.5 haiku'],
    description: 'Quick Claude for low-cost chats.',
    rank: 64,
  ),
  CuratedModel(
    key: 'anthropic-claude3-haiku',
    displayName: 'Claude 3 Haiku',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-3-haiku',
    aliases: ['claude 3 haiku'],
    description: 'Older lightweight Claude model.',
    rank: 50,
  ),
  CuratedModel(
    key: 'anthropic-claude-opus-41',
    displayName: 'Claude Opus 4.1',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-opus-4.1',
    aliases: ['claude opus 4.1'],
    description: 'High-end Claude variant for advanced work.',
    supportsReasoning: true,
    rank: 71,
  ),
  CuratedModel(
    key: 'anthropic-claude-opus-4',
    displayName: 'Claude Opus 4',
    provider: 'Anthropic',
    preferredId: 'anthropic/claude-opus-4',
    aliases: ['claude opus 4'],
    description: 'Premium Anthropic model for serious tasks.',
    supportsReasoning: true,
    rank: 69,
  ),

  // Google
  CuratedModel(
    key: 'google-gemini-25-flash',
    displayName: 'Gemini 2.5 Flash',
    provider: 'Google',
    preferredId: 'google/gemini-2.5-flash',
    aliases: ['gemini 2.5 flash'],
    description: 'Fast Gemini with huge context.',
    popular: true,
    supportsVision: true,
    rank: 94,
  ),
  CuratedModel(
    key: 'google-gemini-25-pro',
    displayName: 'Gemini 2.5 Pro Experimental',
    provider: 'Google',
    preferredId: 'google/gemini-2.5-pro-experimental',
    aliases: ['gemini 2.5 pro experimental', 'gemini 2.5 pro'],
    description: 'Premium Gemini model for analysis and research.',
    popular: true,
    supportsReasoning: true,
    supportsVision: true,
    rank: 89,
  ),
  CuratedModel(
    key: 'google-gemini-20-flash-lite',
    displayName: 'Gemini 2.0 Flash Lite',
    provider: 'Google',
    preferredId: 'google/gemini-2.0-flash-lite',
    aliases: ['gemini 2.0 flash lite'],
    description: 'Cheap fast Gemini option.',
    rank: 67,
  ),
  CuratedModel(
    key: 'google-gemini-15-flash',
    displayName: 'Gemini 1.5 Flash',
    provider: 'Google',
    preferredId: 'google/gemini-1.5-flash',
    aliases: ['gemini 1.5 flash'],
    description: 'Large-context Gemini for fast daily usage.',
    popular: true,
    supportsVision: true,
    rank: 82,
  ),
  CuratedModel(
    key: 'google-gemini-15-pro',
    displayName: 'Gemini 1.5 Pro',
    provider: 'Google',
    preferredId: 'google/gemini-1.5-pro',
    aliases: ['gemini 1.5 pro'],
    description: 'Strong Gemini for long-context and analysis.',
    popular: true,
    supportsReasoning: true,
    supportsVision: true,
    rank: 81,
  ),
  CuratedModel(
    key: 'google-nano-banana',
    displayName: 'Nano Banana (Gemini 2.5 Flash Image)',
    provider: 'Google',
    preferredId: 'google/nano-banana',
    aliases: ['nano banana', 'gemini 2.5 flash image'],
    description: 'Google image-capable Gemini variant.',
    popular: true,
    supportsVision: true,
    rank: 79,
  ),
  CuratedModel(
    key: 'google-gemma-3-27b',
    displayName: 'Gemma 3 27B',
    provider: 'Google',
    preferredId: 'google/gemma-3-27b',
    aliases: ['gemma 3 27b'],
    description: 'Strong open Google model with good value.',
    popular: true,
    supportsCoding: true,
    rank: 75,
  ),
  CuratedModel(
    key: 'google-gemma-3-12b',
    displayName: 'Gemma 3 12B',
    provider: 'Google',
    preferredId: 'google/gemma-3-12b',
    aliases: ['gemma 3 12b'],
    description: 'Balanced Gemma model.',
    rank: 63,
  ),
  CuratedModel(
    key: 'google-gemma-3-4b',
    displayName: 'Gemma 3 4B',
    provider: 'Google',
    preferredId: 'google/gemma-3-4b',
    aliases: ['gemma 3 4b'],
    description: 'Small Gemma for cheap tasks.',
    rank: 46,
  ),
  CuratedModel(
    key: 'google-gemma-2-9b',
    displayName: 'Gemma 2 9B',
    provider: 'Google',
    preferredId: 'google/gemma-2-9b',
    aliases: ['gemma 2 9b'],
    description: 'Older but useful Gemma option.',
    rank: 42,
  ),

  // xAI
  CuratedModel(
    key: 'xai-grok-41-fast',
    displayName: 'Grok 4.1 Fast',
    provider: 'xAI',
    preferredId: 'x-ai/grok-4.1-fast',
    aliases: ['grok 4.1 fast'],
    description: 'Fast long-context Grok model.',
    popular: true,
    rank: 88,
  ),
  CuratedModel(
    key: 'xai-grok-4',
    displayName: 'Grok 4',
    provider: 'xAI',
    preferredId: 'x-ai/grok-4',
    aliases: ['grok 4'],
    description: 'Premium Grok model for broad assistant tasks.',
    popular: true,
    supportsReasoning: true,
    rank: 84,
  ),
  CuratedModel(
    key: 'xai-grok-4-fast',
    displayName: 'Grok 4 Fast',
    provider: 'xAI',
    preferredId: 'x-ai/grok-4-fast',
    aliases: ['grok 4 fast'],
    description: 'Fast Grok 4 variant.',
    popular: true,
    rank: 77,
  ),
  CuratedModel(
    key: 'xai-grok-3',
    displayName: 'Grok 3',
    provider: 'xAI',
    preferredId: 'x-ai/grok-3',
    aliases: ['grok 3'],
    description: 'High-end Grok model.',
    popular: true,
    rank: 73,
  ),
  CuratedModel(
    key: 'xai-grok-3-mini',
    displayName: 'Grok 3 Mini',
    provider: 'xAI',
    preferredId: 'x-ai/grok-3-mini',
    aliases: ['grok 3 mini'],
    description: 'Smaller Grok for lighter tasks.',
    rank: 54,
  ),
  CuratedModel(
    key: 'xai-grok-code-fast-1',
    displayName: 'Grok Code Fast 1',
    provider: 'xAI',
    preferredId: 'x-ai/grok-code-fast-1',
    aliases: ['grok code fast 1'],
    description: 'Coding-first Grok model with strong speed.',
    popular: true,
    supportsCoding: true,
    rank: 80,
  ),
  CuratedModel(
    key: 'xai-grok-2-vision-1212',
    displayName: 'Grok 2 Vision 1212',
    provider: 'xAI',
    preferredId: 'x-ai/grok-2-vision-1212',
    aliases: ['grok 2 vision 1212'],
    description: 'Vision-enabled Grok 2 variant.',
    supportsVision: true,
    rank: 48,
  ),

  // Qwen
  CuratedModel(
    key: 'qwen-qwen35-flash',
    displayName: 'Qwen3.5 Flash',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3.5-flash',
    aliases: ['qwen3.5 flash'],
    description: 'Fast new-generation Qwen model.',
    popular: true,
    rank: 87,
  ),
  CuratedModel(
    key: 'qwen-next-80b-instruct',
    displayName: 'Qwen3 Next 80B A3B Instruct',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-next-80b-a3b-instruct',
    aliases: ['qwen3 next 80b a3b instruct'],
    description: 'Large instruct-tuned Qwen model.',
    popular: true,
    rank: 78,
  ),
  CuratedModel(
    key: 'qwen-next-80b-thinking',
    displayName: 'Qwen3 Next 80B A3B Thinking',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-next-80b-a3b-thinking',
    aliases: ['qwen3 next 80b a3b thinking'],
    description: 'Reasoning-oriented Qwen model.',
    supportsReasoning: true,
    rank: 66,
  ),
  CuratedModel(
    key: 'qwen-235b-instruct',
    displayName: 'Qwen3 235B A22B Instruct 2507',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-235b-a22b-instruct-2507',
    aliases: ['qwen3 235b a22b instruct 2507'],
    description: 'Huge Qwen instruct model with strong value.',
    popular: true,
    rank: 76,
  ),
  CuratedModel(
    key: 'qwen-235b-thinking',
    displayName: 'Qwen3 235B A22B Thinking 2507',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-235b-a22b-thinking-2507',
    aliases: ['qwen3 235b a22b thinking 2507'],
    description: 'Premium Qwen reasoning model.',
    supportsReasoning: true,
    rank: 61,
  ),
  CuratedModel(
    key: 'qwen-32b',
    displayName: 'Qwen3 32B',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-32b',
    aliases: ['qwen3 32b'],
    description: 'General-purpose 32B Qwen model.',
    rank: 57,
  ),
  CuratedModel(
    key: 'qwen-14b',
    displayName: 'Qwen3 14B',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-14b',
    aliases: ['qwen3 14b'],
    description: 'Balanced medium-size Qwen.',
    rank: 45,
  ),
  CuratedModel(
    key: 'qwen-coder-30b',
    displayName: 'Qwen3 Coder 30B A3B Instruct',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-coder-30b-a3b-instruct',
    aliases: ['qwen3 coder 30b a3b instruct'],
    description: 'Qwen coding-focused model.',
    popular: true,
    supportsCoding: true,
    rank: 74,
  ),
  CuratedModel(
    key: 'qwen-vl-30b-instruct',
    displayName: 'Qwen3 VL 30B A3B Instruct',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-vl-30b-a3b-instruct',
    aliases: ['qwen3 vl 30b a3b instruct'],
    description: 'Qwen multimodal model with strong vision support.',
    popular: true,
    supportsVision: true,
    rank: 72,
  ),
  CuratedModel(
    key: 'qwen-vl-8b-instruct',
    displayName: 'Qwen3 VL 8B Instruct',
    provider: 'Qwen',
    preferredId: 'qwen/qwen3-vl-8b-instruct',
    aliases: ['qwen3 vl 8b instruct'],
    description: 'Compact instruct Qwen with vision.',
    supportsVision: true,
    rank: 49,
  ),

  // DeepSeek / Mistral / Others
  CuratedModel(
    key: 'deepseek-r1-0528',
    displayName: 'DeepSeek R1 0528',
    provider: 'DeepSeek',
    preferredId: 'deepseek/deepseek-r1-0528',
    aliases: ['deepseek r1 0528', 'deepseek r1'],
    description: 'Popular reasoning-first DeepSeek model.',
    popular: true,
    supportsReasoning: true,
    supportsCoding: true,
    rank: 85,
  ),
  CuratedModel(
    key: 'mistral-large-3-2512',
    displayName: 'Mistral Large 3 2512',
    provider: 'Mistral',
    preferredId: 'mistralai/mistral-large-3-2512',
    aliases: ['mistral large 3 2512'],
    description: 'Newer high-end Mistral model.',
    popular: true,
    supportsCoding: true,
    rank: 71,
  ),
  CuratedModel(
    key: 'mistral-devstral-2-2512',
    displayName: 'Devstral 2 2512',
    provider: 'Mistral',
    preferredId: 'mistralai/devstral-2-2512',
    aliases: ['devstral 2 2512'],
    description: 'Coding-oriented Mistral family model.',
    supportsCoding: true,
    rank: 52,
  ),
  CuratedModel(
    key: 'mistral-medium-31',
    displayName: 'Mistral Medium 3.1',
    provider: 'Mistral',
    preferredId: 'mistralai/mistral-medium-3.1',
    aliases: ['mistral medium 3.1'],
    description: 'Balanced Mistral medium model.',
    rank: 47,
  ),
  CuratedModel(
    key: 'mistral-mixtral-8x7b',
    displayName: 'Mixtral 8x7B Instruct',
    provider: 'Mistral',
    preferredId: 'mistralai/mixtral-8x7b-instruct',
    aliases: ['mixtral 8x7b instruct'],
    description: 'Popular open MoE model with strong value.',
    popular: true,
    supportsCoding: true,
    rank: 68,
  ),
  CuratedModel(
    key: 'cohere-command-r',
    displayName: 'Command R (08-2024)',
    provider: 'Cohere',
    preferredId: 'cohere/command-r-08-2024',
    aliases: ['command r 08 2024', 'command r'],
    description: 'Balanced Cohere model for practical work.',
    popular: true,
    supportsTools: true,
    rank: 65,
  ),
  CuratedModel(
    key: 'cohere-command-r-plus',
    displayName: 'Command R+ (08-2024)',
    provider: 'Cohere',
    preferredId: 'cohere/command-r-plus-08-2024',
    aliases: ['command r plus 08 2024', 'command r+'],
    description: 'Retrieval-friendly enterprise-style model.',
    supportsTools: true,
    rank: 53,
  ),
  CuratedModel(
    key: 'amazon-nova-2-lite',
    displayName: 'Nova 2 Lite',
    provider: 'Amazon',
    preferredId: 'amazon/nova-2-lite',
    aliases: ['nova 2 lite'],
    description: 'Fast Amazon model with huge context.',
    popular: true,
    rank: 70,
  ),
  CuratedModel(
    key: 'amazon-nova-pro-1',
    displayName: 'Nova Pro 1.0',
    provider: 'Amazon',
    preferredId: 'amazon/nova-pro-1.0',
    aliases: ['nova pro 1.0'],
    description: 'Balanced Amazon Nova model.',
    rank: 51,
  ),
  CuratedModel(
    key: 'zai-glm47',
    displayName: 'GLM 4.7',
    provider: 'Z.ai',
    preferredId: 'z-ai/glm-4.7',
    aliases: ['glm 4.7'],
    description: 'Fast growing GLM flagship model.',
    popular: true,
    rank: 69,
  ),
  CuratedModel(
    key: 'zai-glm46',
    displayName: 'GLM 4.6',
    provider: 'Z.ai',
    preferredId: 'z-ai/glm-4.6',
    aliases: ['glm 4.6'],
    description: 'Balanced GLM model with strong context.',
    rank: 44,
  ),
  CuratedModel(
    key: 'minimax-m1',
    displayName: 'MiniMax M1',
    provider: 'MiniMax',
    preferredId: 'minimax/minimax-m1',
    aliases: ['minimax m1'],
    description: 'Large-context MiniMax model.',
    rank: 43,
  ),
  CuratedModel(
    key: 'kimi-k2-0905',
    displayName: 'Kimi K2 0905',
    provider: 'MoonshotAI',
    preferredId: 'moonshotai/kimi-k2-0905',
    aliases: ['kimi k2 0905'],
    description: 'Kimi model with strong value and context.',
    popular: true,
    rank: 67,
  ),
  CuratedModel(
    key: 'arcee-coder-large',
    displayName: 'Coder Large',
    provider: 'Arcee AI',
    preferredId: 'arcee-ai/coder-large',
    aliases: ['coder large'],
    description: 'Coding-oriented non-mainstream pick.',
    supportsCoding: true,
    rank: 41,
  ),
];

List<CuratedModel> get mixedOfficialModels {
  final models = List<CuratedModel>.from(curatedOfficialModels);
  models.sort((a, b) {
    final rankCompare = b.rank.compareTo(a.rank);
    if (rankCompare != 0) return rankCompare;

    final popCompare = (b.popular ? 1 : 0).compareTo(a.popular ? 1 : 0);
    if (popCompare != 0) return popCompare;

    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return models;
}

List<CuratedModel> get popularModels {
  final items = curatedOfficialModels.where((m) => m.popular).toList();
  items.sort((a, b) => b.rank.compareTo(a.rank));
  return items;
}

CuratedModel? findCuratedModelById(String id) {
  final raw = id.trim();
  for (final m in curatedOfficialModels) {
    if (m.id == raw || m.preferredId == raw) return m;
  }
  return null;
}

CuratedModel? findCuratedModelByKey(String key) {
  final needle = _normalize(key);
  for (final m in curatedOfficialModels) {
    if (_normalize(m.key) == needle) return m;
  }
  return null;
}

CuratedModel? findCuratedModelByAnyKey(String raw) {
  final needle = _normalize(raw);
  if (needle.isEmpty) return null;

  for (final m in curatedOfficialModels) {
    if (_normalize(m.key) == needle) return m;
    if (_normalize(m.preferredId) == needle) return m;
    if (m.normalizedDisplayName == needle) return m;
    if (m.normalizedAliases.contains(needle)) return m;
  }
  return null;
}

List<CuratedModel> searchCuratedModels({
  String query = '',
  ExploreFilter filter = ExploreFilter.official,
}) {
  final q = _normalize(query);
  final base = switch (filter) {
    ExploreFilter.official => mixedOfficialModels,
    ExploreFilter.popular => popularModels,
  };

  if (q.isEmpty) return List<CuratedModel>.from(base);

  final out = base.where((m) {
    if (m.normalizedDisplayName.contains(q)) return true;
    if (_normalize(m.provider).contains(q)) return true;
    if (_normalize(m.description).contains(q)) return true;
    if (_normalize(m.preferredId).contains(q)) return true;
    return m.normalizedAliases.any((a) => a.contains(q));
  }).toList();

  out.sort((a, b) => b.rank.compareTo(a.rank));
  return out;
}