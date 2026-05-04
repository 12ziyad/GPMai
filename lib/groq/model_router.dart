import 'dart:async';

import '../services/gpmai_api_client.dart';

/// Router that talks ONLY to your Cloudflare Worker (/chat via OpenRouter)
/// - No API keys in the app
/// - Uses your Worker: /health + /chat
/// - Keeps the same getResponse(...) signature used in your codebase
class ModelRouter {
  /// Main entry: returns plain text.
  /// - prompt: user text
  /// - modelOverride: optional model id (if null/empty -> server defaultModel from Firestore)
  /// - retries: auto-retry on temporary errors
  /// - contentParts: optional multimodal parts (we'll convert to text for now)
  static Future<String> getResponse(
    String prompt, {
    String? modelOverride,
    int retries = 2,
    List<Map<String, dynamic>>? contentParts,
  }) async {
    // ✅ IMPORTANT:
    // If user didn't explicitly choose a model, DO NOT force a fallback here.
    // Let the server pick cfg.defaultModel from Firestore (config/public).
    final cleanedOverride = modelOverride?.trim();
    final String? modelId =
        (cleanedOverride != null && cleanedOverride.isNotEmpty) ? cleanedOverride : null;

    // ✅ For now: if contentParts provided, try to pull text and append to prompt
    // (Image support needs worker changes; we’ll do that later)
    final extracted = _extractTextFromParts(contentParts);
    final finalPrompt = extracted.isEmpty ? prompt : '$prompt\n\n$extracted';

    try {
      // Build OpenAI-chat style messages (OpenRouter compatible)
      final messages = <Map<String, dynamic>>[
        {
          "role": "user",
          "content": finalPrompt,
        }
      ];

      final res = await GpmaiApiClient.chat(
        messages: messages,
        model: modelId, // ✅ can be null => server uses Firestore defaultModel
      ).timeout(const Duration(seconds: 60));

      final text = _extractChatText(res);
      return text.isEmpty ? '[No response]' : text;
    } on TimeoutException {
      return '[Network] Request timed out';
    } catch (e) {
      // retry on common network-like failures
      if (retries > 0) {
        await Future.delayed(const Duration(seconds: 1));
        return getResponse(
          prompt,
          modelOverride: modelOverride,
          retries: retries - 1,
          contentParts: contentParts,
        );
      }
      return '[Network] $e';
    }
  }

  /// Extract assistant text from OpenRouter/OpenAI chat completion JSON
  static String _extractChatText(Map<String, dynamic> j) {
    try {
      final choices = j['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final msg = first['message'];
          if (msg is Map) {
            final content = msg['content'];
            if (content is String) return content.trim();
          }
        }
      }
    } catch (_) {}
    return '';
  }

  /// Pulls any text parts we can (ignore image for now)
  static String _extractTextFromParts(List<Map<String, dynamic>>? parts) {
    if (parts == null || parts.isEmpty) return '';
    final buf = StringBuffer();
    for (final p in parts) {
      final type = (p['type'] ?? '').toString();
      if (type == 'text') {
        final t = (p['text'] ?? '').toString().trim();
        if (t.isNotEmpty) buf.writeln(t);
      }
    }
    return buf.toString().trim();
  }
}
