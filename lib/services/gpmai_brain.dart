import 'dart:async';
import 'dart:math' as math;

import 'gpmai_api_client.dart';
import 'model_prefs.dart';
import 'curated_models.dart';
import 'memory_session.dart';

class BrainResult {
  final String text;
  final Map<String, dynamic> raw;
  final bool fallback;
  final bool cooldown;
  final String usedUiModel;
  final String? plan;

  const BrainResult({
    required this.text,
    this.raw = const {},
    this.fallback = false,
    this.cooldown = false,
    this.usedUiModel = '',
    this.plan,
  });
}

class GPMaiBrain {
  static String model = ModelPrefs.fallbackModelId;
  static String defaultUiModel = ModelPrefs.fallbackModelId;

  static Future<String> send(
    String prompt, {
    String? systemPrompt,
    String? userId,
    String? chatId,
    String? uiModel,
    String? modelOverride,
    bool? store,
    double? temperature,
    int? maxOutputTokens,
    String sourceTag = 'chat',
    String? clientMsgId,
  }) async {
    final r = await sendRich(
      prompt: prompt,
      systemPrompt: systemPrompt,
      userId: userId,
      chatId: chatId,
      uiModel: uiModel,
      modelOverride: modelOverride,
      store: store,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
      sourceTag: sourceTag,
      clientMsgId: clientMsgId,
    );
    return r.text;
  }

  static Future<BrainResult> sendRich({
    String? prompt,
    String? userText,
    String? input,
    String? systemPrompt,
    String? userId,
    String? chatId,
    String? uiModel,
    String? modelOverride,
    List<dynamic>? contentParts,
    bool? store,
    double? temperature,
    int? maxOutputTokens,
    String sourceTag = 'chat',
    Duration timeout = const Duration(seconds: 90),
    String? clientMsgId,
  }) async {
    final finalInput = (userText ?? input ?? prompt ?? '').trim();
    if (finalInput.isEmpty) {
      return const BrainResult(text: '[Error] Empty input.');
    }

    final chosenModel = await _chooseModelId(
      uiModel: uiModel,
      modelOverride: modelOverride,
    );

    final effectiveClientMsgId = (clientMsgId != null && clientMsgId.isNotEmpty)
        ? clientMsgId
        : 'gpmai_${chatId ?? 'nochat'}_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(999999)}';

    // ✅ Debug log: this is the real model id chosen before request
    print('🧠 GPMaiBrain chosenModel = $chosenModel');

    model = chosenModel;
    defaultUiModel = chosenModel;

    final messages = <Map<String, dynamic>>[];

    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': systemPrompt.trim(),
      });
    }

    if (contentParts != null && contentParts.isNotEmpty) {
      final parts = <Map<String, dynamic>>[
        {'type': 'text', 'text': finalInput},
        ...contentParts.cast<Map<String, dynamic>>(),
      ];

      messages.add({
        'role': 'user',
        'content': parts,
      });
    } else {
      messages.add({
        'role': 'user',
        'content': finalInput,
      });
    }

    try {
      final raw = await GpmaiApiClient.chat(
        messages: messages,
        model: chosenModel,
        maxTokens: maxOutputTokens,
        temperature: temperature,
        sourceTag: sourceTag,
        memoryMode: MemorySession.activeMode,
        chatId: chatId,
        threadId: chatId,
        conversationId: chatId,
        clientMsgId: effectiveClientMsgId,
      ).timeout(timeout);

      final text = _extractChatText(raw).trim();
      if (text.isEmpty) {
        return BrainResult(
          text: '[Error] Empty reply.',
          raw: raw,
          fallback: true,
          cooldown: false,
          usedUiModel: chosenModel,
        );
      }

      return BrainResult(
        text: text,
        raw: raw,
        fallback: false,
        cooldown: false,
        usedUiModel: chosenModel,
      );
    } on TimeoutException {
      return BrainResult(
        text: '[Error] Timeout talking to Cloudflare.',
        fallback: true,
        cooldown: false,
        usedUiModel: chosenModel,
      );
    } catch (e) {
      return BrainResult(
        text: '[Error] $e',
        fallback: true,
        cooldown: false,
        usedUiModel: chosenModel,
      );
    }
  }

  static Future<String> _chooseModelId({
    String? uiModel,
    String? modelOverride,
  }) async {
    final candidates = <String?>[
      modelOverride,
      uiModel,
      model,
      await ModelPrefs.getSelected(),
      defaultUiModel,
    ];

    for (final candidate in candidates) {
      final resolved = _sanitizeModelId(candidate);
      if (resolved != null) return resolved;
    }

    return ModelPrefs.fallbackModelId;
  }

  static String? _sanitizeModelId(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return null;

    // Full curated id
    final byId = findCuratedModelById(v);
    if (byId != null) return byId.id;

    // By alias/key/display name
    final byAny = findCuratedModelByAnyKey(v);
    if (byAny != null) return byAny.id;

    // Legacy shortcuts
    switch (v.toLowerCase()) {
      case 'gpt52':
      case 'gpt5':
      case 'gpt-5':
      case 'gpt51':
      case 'gpt-5.1':
      case 'gpt5mini':
      case 'gpt-5-mini':
      case 'mini':
        return 'openai/gpt-5-mini';

      case 'gpt41mini':
      case 'gpt-4.1-mini':
        return 'openai/gpt-4.1-mini';

      case 'o1mini':
      case 'o1-mini':
        return 'openai/o1-mini';

      case 'claude':
      case 'claude-sonnet':
      case 'claude-sonnet-4.6':
        return 'anthropic/claude-sonnet-4.6';

      case 'gemini':
      case 'gemini-flash':
      case 'gemini-1.5-flash':
        return 'google/gemini-1.5-flash';

      default:
        return null;
    }
  }

  static String _extractChatText(Map<String, dynamic> raw) {
    try {
      final choices = raw['choices'];
      if (choices is List && choices.isNotEmpty) {
        final msg = choices.first['message'];
        if (msg is Map) {
          final content = msg['content'];
          if (content is String) return content;
          if (content is List) {
            final buf = StringBuffer();
            for (final c in content) {
              if (c is Map && c['type'] == 'text') {
                buf.writeln((c['text'] ?? '').toString());
              }
            }
            return buf.toString();
          }
        }
      }
    } catch (_) {}
    return '';
  }
}