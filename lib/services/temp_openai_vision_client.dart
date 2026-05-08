// Temporary direct-OpenAI path for local testing only.
// Enabled only when --dart-define=ORB_TEMP_DIRECT_OPENAI=true is passed.
// Remove this file after testing is complete.
import 'dart:convert';
import 'package:http/http.dart' as http;

abstract final class TempOpenAIVisionClient {
  static const bool _enabled =
      bool.fromEnvironment('ORB_TEMP_DIRECT_OPENAI', defaultValue: false);
  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');

  static bool get isEnabled => _enabled && _apiKey.isNotEmpty;
  static bool get keyPresent => _apiKey.isNotEmpty;

  static void logStatus() {
    _log('enabled=$_enabled keyPresent=${_apiKey.isNotEmpty}');
  }

  // ── Vision call (text + optional screenshot) ─────────────────────────────

  static Future<String> ask({
    required String question,
    required String screenText,
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    final hasImage = imageBase64.isNotEmpty;
    _log('request start model=gpt-4o-mini hasImage=$hasImage imageLen=${imageBase64.length} screenTextLen=${screenText.length}');

    // No image and no screen text — nothing to work with.
    if (!hasImage && screenText.isEmpty) {
      return 'Screenshot was not received. Please allow screen capture or ask again.';
    }

    final systemInstructions = hasImage
        ? 'You are GPMai Orb, a screen-aware assistant.\n'
            'You are receiving the user\'s current phone screenshot as an image.\n'
            'Use the screenshot first, then OCR/accessibility text as backup.\n'
            'Do not say you cannot see the screen if an image is provided.\n'
            'Answer the user\'s question directly and specifically.'
        : 'You are GPMai Orb, a screen-aware assistant.\n'
            'Screenshot was not received. I can only use visible text.\n'
            'Answer from the accessibility/OCR text provided.';

    final textBody = StringBuffer();
    textBody.write(systemInstructions);
    textBody.write('\n\nUser question:\n$question');
    if (screenText.isNotEmpty) {
      textBody.write('\n\nVisible text extracted from screen:\n$screenText');
    }

    final userContent = <Map<String, dynamic>>[
      {'type': 'text', 'text': textBody.toString()},
    ];

    if (hasImage) {
      userContent.add({
        'type': 'image_url',
        'image_url': {'url': 'data:$mimeType;base64,$imageBase64'},
      });
    }

    return _post(userContent);
  }

  // ── Text-only call (chat box / fallback) ─────────────────────────────────

  static Future<String> askTextTemp({
    required String question,
    String screenText = '',
  }) async {
    _log('request start model=gpt-4o-mini hasImage=false screenTextLen=${screenText.length}');

    final text = screenText.trim().isEmpty
        ? 'You are GPMai Orb. Answer concisely.\n\nUser: $question'
        : 'You are GPMai Orb. Answer concisely.\n\n'
            'Screen context: $screenText\n\nUser: $question';

    return _post([
      {'type': 'text', 'text': text},
    ]);
  }

  // ── Shared POST ───────────────────────────────────────────────────────────

  static Future<String> _post(List<Map<String, dynamic>> userContent) async {
    logStatus();
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'user', 'content': userContent},
      ],
      'max_tokens': 700,
      'temperature': 0.3,
    });

    try {
      final r = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      _log('status=${r.statusCode}');

      if (r.statusCode != 200) {
        final preview =
            r.body.length > 200 ? r.body.substring(0, 200) : r.body;
        _log('error preview=$preview');
        return '[TempOpenAI] error ${r.statusCode}';
      }

      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final text = _extractText(j);
      return text.isEmpty ? '[No response]' : text;
    } catch (e) {
      _log('error preview=$e');
      return '[TempOpenAI] exception: $e';
    }
  }

  static String _extractText(Map<String, dynamic> j) {
    try {
      final choices = j['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final content = (choices.first as Map)['message']?['content'];
        if (content is String) return content.trim();
      }
    } catch (_) {}
    return '';
  }

  static void _log(String msg) {
    // ignore: avoid_print
    print('[TempOpenAI] $msg');
  }
}
