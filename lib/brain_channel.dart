// lib/brain_channel.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BrainChannel {
  BrainChannel._();

  // Keep your existing default model id
  static const String _defaultModel = 'gpt-5-mini-2025-08-07';
  static const int _maxOutputTokens = 512;

  // ✅ Use your Vercel proxy (NO API key on client)
  static const String _proxyUrl =
      'https://gpmai-proxy-vercel-mz4tnyyql-ziyads-projects-285bba39.vercel.app/api/responses';

  static const MethodChannel _channel = MethodChannel('gpmai/brain');

  // Flags
  static bool _inVision = false;
  static bool _firstAsk = true;

  // -------------- Init & native calls --------------
  static void init() {
    _channel.setMethodCallHandler(_onNativeCall);
    _log('BrainChannel ready');
  }

  static Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'handleVisionMessage':
        final Map payload = (call.arguments as Map?) ?? {};
        return await visionFirst(
          question: (payload['question'] ?? '').toString(),
          imageBase64Jpeg: (payload['image_base64_jpeg'] ?? '').toString(),
          a11y: (payload['a11y_text'] ?? '').toString(),
          ocr: (payload['ocr_text'] ?? '').toString(),
        );
      case 'handleUserMessage':
        return await textOnly(
          system: 'You answer briefly (1–2 lines).',
          user: (call.arguments ?? '').toString(),
        );
      default:
        return null;
    }
  }

  // -------------- Vision-first (15s) --------------
  static Future<String> visionFirst({
    required String question,
    required String imageBase64Jpeg,
    required String a11y,
    required String ocr,
  }) async {
    if (_inVision) {
      _log("VisionFirst already running, skipping re-entry.");
      return "[busy]";
    }
    _inVision = true;

    try {
      if (_firstAsk) {
        _log("First ask may take longer (warming up HTTP/TLS)…");
      }

      final dataUrl = 'data:image/jpeg;base64,$imageBase64Jpeg';
      final visionInput = [
        {
          "role": "user",
          "content": [
            {"type": "input_text", "text": _visionSystemFewshot()},
            {"type": "input_text", "text": "Question: $question"},
            {"type": "input_image", "image_url": dataUrl}
          ]
        }
      ];

      final started = DateTime.now().millisecondsSinceEpoch;
      _log("VisionFirst → POST /responses (image-only)");
      String visionText;
      try {
        visionText = await _responses(
          model: _defaultModel,
          input: visionInput,
          tag: 'VisionFirst',
        ).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        final dt = DateTime.now().millisecondsSinceEpoch - started;
        _log("❌ VisionFirst timeout (15s) → will fallback (dt=${dt}ms)");
        visionText = "[No response]";
      }

      if (_usable(visionText)) {
        final dt = DateTime.now().millisecondsSinceEpoch - started;
        _log('VisionFirst OK in ${dt}ms → "${_oneline(visionText)}"');
        _firstAsk = false;
        return visionText;
      }

      // ↩️ Fallback (no timeout)
      _log("!  Fallback → empty-or-no-response | Using OCR + a11y text");
      final fbPrompt = """
The user asked about the current screen.

QUESTION:
$question

ACCESSIBILITY:
$a11y

OCR:
$ocr
""";
      final fbStart = DateTime.now().millisecondsSinceEpoch;
      _log("TextOnlyFallback → POST /responses (text-only) [no-timeout]");
      final textAns = await textOnly(
        system: 'Answer briefly (1–2 lines).',
        user: fbPrompt,
        tag: 'TextOnlyFallback',
      );
      final fbDt = DateTime.now().millisecondsSinceEpoch - fbStart;
      _log('TextOnlyFallback done in ${fbDt}ms → "${_oneline(textAns)}"');

      _firstAsk = false;
      return _usable(textAns) ? textAns : "[No response]";
    } finally {
      _inVision = false;
    }
  }

  // -------------- Text-only helper --------------
  static Future<String> textOnly({
    required String system,
    required String user,
    String tag = 'TextOnly',
  }) async {
    final input = [
      {"role": "system", "content": [{"type": "input_text", "text": system}]},
      {"role": "user", "content": [{"type": "input_text", "text": user}]}
    ];
    return _responses(model: _defaultModel, input: input, tag: tag);
  }

  // -------------- Core /responses caller --------------
  static Future<String> _responses({
    required String model,
    required List<Map<String, dynamic>> input,
    required String tag,
  }) async {
    final uri = Uri.parse(_proxyUrl);
    final body = jsonEncode({
      "model": model,
      "input": input,
      "max_output_tokens": _maxOutputTokens,
      "stream": false,
    });

    final began = DateTime.now().millisecondsSinceEpoch;
    _log("$tag → POST /responses (${_kindFromInput(input)})");

    try {
      final r = await http.post(
        uri,
        headers: const {
          // ✅ No Authorization header — proxy injects the key
          'Content-Type': 'application/json',
        },
        body: body,
      );

      final dt = DateTime.now().millisecondsSinceEpoch - began;

      if (r.statusCode != 200) {
        _log("❌ $tag error: ${r.statusCode} ${r.body}");
        return "[No response]";
      }

      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final txt = _extractAssistantTextFromResponsesJson(j);
      final res = txt.isNotEmpty ? txt : "[No response]";
      _log('$tag done in ${dt}ms → "${_oneline(res)}"');
      return res;
    } catch (e) {
      final dt = DateTime.now().millisecondsSinceEpoch - began;
      _log("❌ $tag exception after ${dt}ms: $e");
      return "[No response]";
    }
  }

  // -------------- JSON extractor --------------
  static String _extractAssistantTextFromResponsesJson(Map<String, dynamic> j) {
    final out = j['output'];
    if (out is List) {
      for (final item in out) {
        if (item is Map && item['type'] == 'message') {
          final content = item['content'];
          if (content is List) {
            for (final c in content) {
              if (c is Map && c['type'] == 'output_text') {
                final txt = (c['text'] ?? '').toString().trim();
                if (txt.isNotEmpty) return txt;
              }
            }
          }
        }
      }
    }
    return '';
  }

  // -------------- Helpers --------------
  static bool _usable(String s) =>
      s.trim().length >= 3 && s.trim() != '[No response]';

  static String _visionSystemFewshot() =>
      "You are helping with an Android phone screen. "
      "Answer in 1–2 short lines, be specific.";

  static String _kindFromInput(List<Map<String, dynamic>> input) {
    try {
      final contents = input.first['content'] as List?;
      if (contents != null) {
        for (final c in contents) {
          if (c is Map && c['type'] == 'input_image') return 'image-only';
        }
      }
    } catch (_) {}
    return 'text-only';
  }

  static void _log(String msg) {
    final ts = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print('🧠[$ts] $msg');
  }

  static String _oneline(String s) {
    final t = s.replaceAll('\n', ' ').trim();
    return (t.length <= 120) ? t : t.substring(0, 120);
  }
}
