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

    final isMultimodal = contentParts != null && contentParts.any((p) {
      final type = (p['type'] ?? '').toString();
      return type == 'image_url' || type == 'image_base64';
    });

    final imageParts = _countImageParts(contentParts);
    final textParts = _countTextParts(contentParts);
    print('[ModelRouter] multimodal=$isMultimodal imageParts=$imageParts textParts=$textParts model=$modelId');

    final messages = <Map<String, dynamic>>[];
    if (isMultimodal) {
      final content = _buildMultimodalContent(prompt, contentParts);
      messages.add({
        "role": "user",
        "content": content,
      });
    } else {
      final extracted = _extractTextFromParts(contentParts);
      final finalPrompt = extracted.isEmpty ? prompt : '$prompt\n\n$extracted';
      messages.add({
        "role": "user",
        "content": finalPrompt,
      });
    }

    try {
      final res = await GpmaiApiClient.chat(
        messages: messages,
        model: modelId, // ✅ can be null => server uses Firestore defaultModel
        sourceTag: isMultimodal ? 'orb_screen' : null,
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

  static List<Map<String, dynamic>> _buildMultimodalContent(
    String prompt,
    List<Map<String, dynamic>>? parts,
  ) {
    final content = <Map<String, dynamic>>[];

    final textBuffer = StringBuffer();
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isNotEmpty) {
      textBuffer.writeln(cleanPrompt);
    }

    for (final p in parts ?? const <Map<String, dynamic>>[]) {
      final type = (p['type'] ?? '').toString();
      if (type == 'text') {
        final t = (p['text'] ?? '').toString().trim();
        if (t.isNotEmpty) textBuffer.writeln('\n$t');
      }
    }

    final finalText = textBuffer.toString().trim();
    if (finalText.isNotEmpty) {
      content.add({
        'type': 'text',
        'text': finalText,
      });
    }

    for (final p in parts ?? const <Map<String, dynamic>>[]) {
      final type = (p['type'] ?? '').toString();
      if (type == 'image_url') {
        String? url;
        final imageUrl = p['image_url'];
        if (imageUrl is Map && imageUrl['url'] != null) {
          url = imageUrl['url'].toString();
        } else if (p['url'] != null) {
          url = p['url'].toString();
        }
        if (url != null && url.trim().isNotEmpty) {
          content.add({
            'type': 'image_url',
            'image_url': {
              'url': url.trim(),
            },
          });
        }
      }

      if (type == 'image_base64') {
        final mimeType = (p['mimeType'] ?? p['mime_type'] ?? 'image/jpeg').toString();
        final data = (p['data'] ?? '').toString().trim();
        if (data.isNotEmpty) {
          content.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:$mimeType;base64,$data',
            },
          });
        }
      }
    }

    return content;
  }

  static int _countImageParts(List<Map<String, dynamic>>? parts) {
    if (parts == null || parts.isEmpty) return 0;
    return parts.where((p) {
      final type = (p['type'] ?? '').toString();
      return type == 'image_url' || type == 'image_base64';
    }).length;
  }

  static int _countTextParts(List<Map<String, dynamic>>? parts) {
    if (parts == null || parts.isEmpty) return 0;
    return parts.where((p) => (p['type'] ?? '').toString() == 'text').length;
  }
}
