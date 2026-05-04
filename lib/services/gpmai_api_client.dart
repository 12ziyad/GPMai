import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../config/api_config.dart';

class GpmaiApiClient {
  static const String unifiedMemoryMode = 'global';

  static Uri _u(String path) => Uri.parse("${ApiConfig.baseUrl}$path");

  static Future<Map<String, String>> _authHeaders() async {
    String? token;
    try {
      final user = FirebaseAuth.instance.currentUser;
      token = await user?.getIdToken();
    } catch (_) {
      token = null;
    }

    final hasToken = token != null && token.isNotEmpty;

    // ignore: avoid_print
    print("ðŸ”[headers] hasToken=$hasToken");

    return {
      "Content-Type": "application/json",      if (hasToken) "Authorization": "Bearer $token",
    };
  }

  static String _normalizedMode(String? mode) {
    final raw = (mode ?? '').trim().toLowerCase();
    return raw.isEmpty ? unifiedMemoryMode : raw;
  }

  /* ------------------------------------------------------------
   * Generic GET helper
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final headers = await _authHeaders();

    Uri url;
    if (query == null || query.isEmpty) {
      url = _u(path);
    } else {
      final base = _u(path);
      url = base.replace(queryParameters: query);
    }

    // ignore: avoid_print
    print("â˜ï¸[getJson] GET $url");

    final res = await http.get(url, headers: headers).timeout(timeout);

    // ignore: avoid_print
    print("â˜ï¸[getJson] status=${res.statusCode}");
    // ignore: avoid_print
    print("â˜ï¸[getJson] raw=${res.body}");

    if (res.statusCode != 200) {
      throw Exception("GET $path failed (${res.statusCode}): ${res.body}");
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /* ------------------------------------------------------------
   * Generic POST helper
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final headers = await _authHeaders();
    final url = _u(path);

    // ignore: avoid_print
    print("â˜ï¸[postJson] POST $url");
    // ignore: avoid_print
    print("â˜ï¸[postJson] body=${jsonEncode(body)}");

    final res = await http
        .post(
          url,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(timeout);

    // ignore: avoid_print
    print("â˜ï¸[postJson] status=${res.statusCode}");
    // ignore: avoid_print
    print("â˜ï¸[postJson] raw=${res.body}");

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final message = (decoded['message'] ?? decoded['error'] ?? res.body).toString();
      throw Exception(message);
    }

    return decoded;
  }

  /* ------------------------------------------------------------
   * Models catalog (GET /models)
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> models({
    String category = 'all',
    String sort = 'recommended',
    String? provider,
    String? q,
  }) {
    final query = <String, String>{
      'category': category,
      'sort': sort,
    };
    if (provider != null && provider.trim().isNotEmpty) {
      query['provider'] = provider.trim().toLowerCase();
    }
    if (q != null && q.trim().isNotEmpty) {
      query['q'] = q.trim();
    }
    return getJson(
      '/models',
      query: query,
      timeout: const Duration(seconds: 30),
    );
  }

  /* ------------------------------------------------------------
   * Prompt Chips (POST /prompt/chips)
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> promptChips({
    required String inputText,
    required String screenContext,
    required String chipType,
    String? model,
  }) async {
    final body = <String, dynamic>{
      'inputText': inputText,
      'screenContext': screenContext,
      'chipType': chipType,
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    };
    return postJson('/prompt/chips', body, timeout: const Duration(seconds: 120));
  }

  /* ------------------------------------------------------------
   * Citation Builder (POST /citations/generate)
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> generateCitations({
    required String responseText,
    required String responseId,
    required String format,
    String? model,
  }) async {
    final body = <String, dynamic>{
      'responseText': responseText,
      'responseId': responseId,
      'format': format,
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    };
    return postJson('/citations/generate', body, timeout: const Duration(seconds: 120));
  }

  /* ------------------------------------------------------------
   * Health (GET /health)
   * ------------------------------------------------------------ */
  static Future<bool> health() async {
    final headers = await _authHeaders();
    final url = _u('/health');

    final res = await http.get(url, headers: headers).timeout(
          const Duration(seconds: 8),
        );

    return res.statusCode == 200 && res.body.trim() == 'ok';
  }

  /* ------------------------------------------------------------
   * Wallet sync (GET /me)
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> me() async {
    return getJson('/me', timeout: const Duration(seconds: 20));
  }

  static Future<Map<String, dynamic>> usageDaily({int days = 7}) async {
    return getJson(
      '/usage/daily',
      query: {'days': '$days'},
      timeout: const Duration(seconds: 20),
    );
  }

  static Future<Map<String, dynamic>> usageMonthly({int months = 6}) async {
    return getJson(
      '/usage/monthly',
      query: {'months': '$months'},
      timeout: const Duration(seconds: 20),
    );
  }

  /* ------------------------------------------------------------
   * Chat (POST /chat)
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> chat({
    required List<Map<String, dynamic>> messages,
    String? model,
    int? maxTokens,
    double? temperature,
    String? sourceTag,
    String? memoryMode,
    String? chatId,
    String? threadId,
    String? conversationId,
    String? clientMsgId,
  }) async {
    final body = <String, dynamic>{
      'messages': messages,
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (temperature != null) 'temperature': temperature,
      if (sourceTag != null && sourceTag.trim().isNotEmpty) 'sourceTag': sourceTag.trim(),
      'memoryMode': _normalizedMode(memoryMode),
      if (chatId != null && chatId.trim().isNotEmpty) 'chatId': chatId.trim(),
      if (threadId != null && threadId.trim().isNotEmpty) 'threadId': threadId.trim(),
      if (conversationId != null && conversationId.trim().isNotEmpty) 'conversationId': conversationId.trim(),
      if (clientMsgId != null && clientMsgId.trim().isNotEmpty) 'clientMsgId': clientMsgId.trim(),
    };

    return postJson(
      '/chat',
      body,
      timeout: const Duration(seconds: 90),
    );
  }

  /* ------------------------------------------------------------
   * Memory Profiles + Graph
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> memoryInit({String? mode}) {
    final query = <String, String>{
      'mode': _normalizedMode(mode),
    };
    return getJson('/memory/init', query: query, timeout: const Duration(seconds: 25));
  }

  static Future<Map<String, dynamic>> memoryProfile({String? mode}) {
    return getJson('/memory/profile', query: {'mode': _normalizedMode(mode)}, timeout: const Duration(seconds: 25));
  }

  static Future<Map<String, dynamic>> memoryProfileSave(Map<String, dynamic> body) {
    final payload = <String, dynamic>{
      'mode': _normalizedMode(body['mode']?.toString()),
      ...body,
    };
    return postJson('/memory/profile/save', payload, timeout: const Duration(seconds: 35));
  }

  static Future<Map<String, dynamic>> memorySetActiveMode({String? mode}) {
    return postJson('/memory/profile/active-mode', {'mode': _normalizedMode(mode)}, timeout: const Duration(seconds: 20));
  }

  static Future<Map<String, dynamic>> memoryGraph({
    String? mode,
    int nodeLimit = 50,
    int edgeLimit = 80,
    int eventLimit = 30,
    int candidateLimit = 30,
    bool includeDebug = false,
  }) {
    return getJson(
      '/memory/graph',
      query: {
        'mode': _normalizedMode(mode),
        'limit': '$nodeLimit',
        'nodeLimit': '$nodeLimit',
        'edgeLimit': '$edgeLimit',
        'edgesLimit': '$edgeLimit',
        'eventLimit': '$eventLimit',
        'eventsLimit': '$eventLimit',
        'candidateLimit': '$candidateLimit',
        'candidatesLimit': '$candidateLimit',
        'includeDebug': includeDebug ? 'true' : 'false',
        'quotaSafe': 'true',
      },
      timeout: const Duration(seconds: 35),
    );
  }

  static Future<Map<String, dynamic>> memoryDebugStatus({
    int logLimit = 20,
    int jobLimit = 20,
    int candidateLimit = 30,
    int eventLimit = 30,
    bool includeFull = false,
  }) {
    return getJson(
      '/memory/debug/status',
      query: {
        'logLimit': '$logLimit',
        'jobLimit': '$jobLimit',
        'candidateLimit': '$candidateLimit',
        'candidatesLimit': '$candidateLimit',
        'eventLimit': '$eventLimit',
        'eventsLimit': '$eventLimit',
        'includeFull': includeFull ? 'true' : 'false',
        'quotaSafe': 'true',
      },
      timeout: const Duration(seconds: 30),
    );
  }

  static Future<Map<String, dynamic>> memoryDebugFull({
    bool full = false,
    int logLimit = 20,
    int jobLimit = 20,
  }) {
    return getJson(
      '/memory/debug/full',
      query: {
        'full': full ? 'true' : 'false',
        'logLimit': '$logLimit',
        'jobLimit': '$jobLimit',
        'quotaSafe': 'true',
      },
      timeout: const Duration(seconds: 30),
    );
  }

  static Future<Map<String, dynamic>> memoryDeleteNode({required String nodeId, String? mode}) {
    return postJson('/memory/node/delete', {'nodeId': nodeId, 'mode': _normalizedMode(mode)}, timeout: const Duration(seconds: 25));
  }

  static Future<Map<String, dynamic>> memorySimulateLearn({String? mode}) {
    return postJson('/memory/simulate-learn', {'mode': _normalizedMode(mode)}, timeout: const Duration(seconds: 25));
  }

  static Future<Map<String, dynamic>> memoryChatPreview({String? mode, String? question}) {
    return postJson('/memory/chat-preview', {
      'mode': _normalizedMode(mode),
      if (question != null && question.trim().isNotEmpty) 'question': question.trim(),
    }, timeout: const Duration(seconds: 25));
  }

  static Future<Map<String, dynamic>> memoryRecallPreview({
    String? mode,
    required List<Map<String, dynamic>> messages,
    String sourceTag = 'chat',
    String? threadId,
    String? chatId,
    String? conversationId,
  }) {
    return postJson('/memory/recall-preview', {
      'mode': _normalizedMode(mode),
      'messages': messages,
      'sourceTag': sourceTag,
      if (threadId != null && threadId.trim().isNotEmpty) 'threadId': threadId.trim(),
      if (chatId != null && chatId.trim().isNotEmpty) 'chatId': chatId.trim(),
      if (conversationId != null && conversationId.trim().isNotEmpty) 'conversationId': conversationId.trim(),
    }, timeout: const Duration(seconds: 45));
  }

  static Future<Map<String, dynamic>> memoryWritePreview({
    String? mode,
    required List<Map<String, dynamic>> messages,
    String assistantText = '',
    String sourceTag = 'chat',
  }) {
    return postJson('/memory/write-preview', {
      'mode': _normalizedMode(mode),
      'messages': messages,
      'assistantText': assistantText,
      'sourceTag': sourceTag,
    }, timeout: const Duration(seconds: 45));
  }


  static Future<Map<String, dynamic>> memoryLearnFlush({
    String? mode,
    required List<Map<String, dynamic>> messages,
    String assistantText = '',
    String sourceTag = 'chat',
    String? threadId,
    String? chatId,
    String? conversationId,
    bool forceExtract = true,
  }) {
    return postJson('/memory/learn/flush', {
      'mode': _normalizedMode(mode),
      'messages': messages,
      'assistantText': assistantText,
      'sourceTag': sourceTag,
      'forceExtract': forceExtract,
      if (threadId != null && threadId.trim().isNotEmpty) 'threadId': threadId.trim(),
      if (chatId != null && chatId.trim().isNotEmpty) 'chatId': chatId.trim(),
      if (conversationId != null && conversationId.trim().isNotEmpty) 'conversationId': conversationId.trim(),
    }, timeout: const Duration(seconds: 60));
  }

  static Future<Map<String, dynamic>> memoryConsolidationStatus() {
    return getJson('/memory/consolidation/status', timeout: const Duration(seconds: 30));
  }

  static Future<Map<String, dynamic>> memoryConsolidationRun({bool dryRun = true}) {
    return postJson('/memory/consolidation/run', {'dryRun': dryRun}, timeout: const Duration(seconds: 60));
  }

  static Future<Map<String, dynamic>> memoryMaintenanceRun() {
    return postJson('/memory/maintenance', const <String, dynamic>{}, timeout: const Duration(seconds: 45));
  }

  static Future<Map<String, dynamic>> memoryFinalStatus({
    bool full = false,
    int logLimit = 20,
    int jobLimit = 20,
  }) {
    return getJson(
      '/memory/final-status',
      query: {
        'full': full ? 'true' : 'false',
        'logLimit': '$logLimit',
        'jobLimit': '$jobLimit',
        'quotaSafe': 'true',
      },
      timeout: const Duration(seconds: 30),
    );
  }

  static Future<Map<String, dynamic>> memoryImportDatedHistory({
    required List<Map<String, dynamic>> entries,
    bool resetLearned = false,
  }) {
    return postJson('/memory/test/import-dated-history', {
      'entries': entries,
      'resetLearned': resetLearned,
    }, timeout: const Duration(seconds: 120));
  }


  static Future<Map<String, dynamic>> memoryResetLearned() {
    return postJson('/memory/reset-learned', const <String, dynamic>{}, timeout: const Duration(seconds: 60));
  }

  static Future<Map<String, dynamic>> memoryBootstrap({
    String? mode,
    required List<Map<String, dynamic>> entries,
    bool resetLearned = false,
  }) {
    return postJson('/memory/bootstrap', {
      'mode': _normalizedMode(mode),
      'entries': entries,
      'resetLearned': resetLearned,
    }, timeout: const Duration(seconds: 120));
  }

  /* ------------------------------------------------------------
   * Media generate (POST /media/generate)
   * ------------------------------------------------------------ */
  static Future<Map<String, dynamic>> mediaGenerate({
    required String category,
    required String modelId,
    required String prompt,
    Map<String, dynamic>? input,
    List<String>? inputUrls,
  }) async {
    final body = <String, dynamic>{
      'category': category,
      'modelId': modelId,
      'prompt': prompt,
      if (input != null) 'input': input,
      if (inputUrls != null && inputUrls.isNotEmpty) 'inputUrls': inputUrls,
    };

    return postJson(
      '/media/generate',
      body,
      timeout: const Duration(seconds: 180),
    );
  }

  /* ------------------------------------------------------------
   * Helpers: parsing
   * ------------------------------------------------------------ */
  static String extractText(Map<String, dynamic> data) {
    final content = data['choices']?[0]?['message']?['content'];
    if (content == null) return '';
    return content.toString();
  }

  static Map<String, dynamic>? extractGpmaiMeta(Map<String, dynamic> data) {
    final m = data['_gpmai'];
    if (m is Map<String, dynamic>) return m;
    return null;
  }
}

