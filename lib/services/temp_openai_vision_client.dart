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

  /// Call once at startup to confirm compile-time values are correct.
  static void logStatus() {
    _log('enabled=$_enabled keyPresent=${_apiKey.isNotEmpty}');
  }

  // ── Vision call (text + optional image) ──────────────────────────────────

  static Future<String> ask({
    required String question,
    required String screenText,
    required String imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    final hasImage = imageBase64.isNotEmpty;
    _log('request start model=gpt-4o-mini hasImage=$hasImage');

    final userContent = <Map<String, dynamic>>[
      {
        'type': 'text',
        'text': 'You are GPMai Orb. Answer concisely.\n\n'
            'Screen context: $screenText\n\nUser: $question',
      },
    ];

    if (hasImage) {
      userContent.add({
        'type': 'image_url',
        'image_url': {'url': 'data:$mimeType;base64,$imageBase64'},
      });
    }

    return _post(userContent);
  }

  // ── Text-only call (chat box) ─────────────────────────────────────────────

  static Future<String> askTextTemp({
    required String question,
    String screenText = '',
  }) async {
    _log('request start model=gpt-4o-mini hasImage=false');

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
