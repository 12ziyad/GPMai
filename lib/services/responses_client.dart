// lib/services/responses_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Drop-in client for your proxy (Vercel).
/// Sends the SAME JSON you'd send to OpenAI /v1/responses.
/// No API key on device; proxy injects it.
class ResponsesClient {
  // Point directly at your Vercel endpoint (includes /api/responses)
  static const String _endpoint =
      'https://gpmai-proxy-vercel-mz4tnyyql-ziyads-projects-285bba39.vercel.app/api/responses';

  /// Returns decoded JSON from the proxy (same as OpenAI would return).
  /// Throws [ResponsesException] with a friendly message on errors.
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final uri = Uri.parse(_endpoint);
    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'}, // no Authorization
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw ResponsesException('Network error: $e');
    }

    final txt = res.body.isEmpty ? '{}' : res.body;
    Map<String, dynamic> json;
    try {
      json = jsonDecode(txt) as Map<String, dynamic>;
    } catch (_) {
      throw ResponsesException(
        'Server sent an invalid response. Please try again.',
        status: res.statusCode,
      );
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json;
    }

    // Surface OpenAI-style error from proxy if present
    final err = json['error'];
    if (err is Map && err['message'] is String) {
      throw ResponsesException(
        err['message'] as String,
        status: res.statusCode,
        code: err['code']?.toString(),
      );
    }

    // Fallback messages
    switch (res.statusCode) {
      case 400:
        throw ResponsesException('Bad request. Update the app and retry.', status: 400);
      case 401:
        throw ResponsesException('Auth failed. Try again later.', status: 401);
      case 413:
        throw ResponsesException('Attachment too large. Try a smaller file.', status: 413);
      case 429:
        throw ResponsesException('Too many requests. Try again in a bit.', status: 429);
      case 502:
      case 503:
      case 504:
        throw ResponsesException('Upstream is temporarily unavailable. Try again soon.',
            status: res.statusCode);
      default:
        throw ResponsesException('Unexpected error (${res.statusCode}).', status: res.statusCode);
    }
  }
}

class ResponsesException implements Exception {
  final String message;
  final int? status;
  final String? code;
  ResponsesException(this.message, {this.status, this.code});
  @override
  String toString() => 'ResponsesException($status, $code): $message';
}
