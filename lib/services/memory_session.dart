import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'gpmai_api_client.dart';
import 'sql_chat_store.dart';

class MemoryProfile {
  final String mode;
  final String name;
  final String role;
  final String projects;
  final String stack;
  final String style;
  final String level;
  final String goals;
  final String avoid;
  final String compressedPrompt;
  final int updatedAt;

  const MemoryProfile({
    required this.mode,
    this.name = '',
    this.role = '',
    this.projects = '',
    this.stack = '',
    this.style = '',
    this.level = '',
    this.goals = '',
    this.avoid = '',
    this.compressedPrompt = '',
    this.updatedAt = 0,
  });

  factory MemoryProfile.empty([String mode = MemorySession.primaryBackendMode]) => MemoryProfile(mode: mode);

  factory MemoryProfile.fromJson(String mode, Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return MemoryProfile(
      mode: (data['activeMode'] ?? data['mode'] ?? mode).toString(),
      name: (data['name'] ?? '').toString(),
      role: (data['focus'] ?? data['role'] ?? data['currentFocus'] ?? '').toString(),
      projects: (data['projects'] ?? data['currentProjects'] ?? '').toString(),
      stack: (data['stack'] ?? data['techStack'] ?? '').toString(),
      style: (data['preferences'] ?? data['style'] ?? data['responsePreferences'] ?? data['communicationStyle'] ?? '').toString(),
      level: (data['level'] ?? data['expertiseLevel'] ?? '').toString(),
      goals: (data['goals'] ?? data['currentGoals'] ?? '').toString(),
      avoid: (data['avoid'] ?? data['whatToAvoid'] ?? '').toString(),
      compressedPrompt: (data['compressedPrompt'] ?? '').toString(),
      updatedAt: int.tryParse('${data['updatedAt'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toPayload() => {
        'mode': mode,
        'name': name,
        'focus': role,
        'projects': projects,
        'stack': stack,
        'preferences': style,
        'goals': goals,
      };

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'name': name,
        'role': role,
        'projects': projects,
        'stack': stack,
        'style': style,
        'level': level,
        'goals': goals,
        'avoid': avoid,
        'compressedPrompt': compressedPrompt,
        'updatedAt': updatedAt,
      };

  MemoryProfile copyWith({
    String? mode,
    String? name,
    String? role,
    String? projects,
    String? stack,
    String? style,
    String? level,
    String? goals,
    String? avoid,
    String? compressedPrompt,
    int? updatedAt,
  }) {
    return MemoryProfile(
      mode: mode ?? this.mode,
      name: name ?? this.name,
      role: role ?? this.role,
      projects: projects ?? this.projects,
      stack: stack ?? this.stack,
      style: style ?? this.style,
      level: level ?? this.level,
      goals: goals ?? this.goals,
      avoid: avoid ?? this.avoid,
      compressedPrompt: compressedPrompt ?? this.compressedPrompt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MemoryNodeData {
  final String id;
  final String label;
  final String group;
  final int level;
  final String parentId;
  final int count;
  final int heat;
  final String info;
  final bool learned;
  final bool isRoot;
  final bool identityDefining;
  final String modeScope;
  final int dateAdded;
  final int lastMentioned;
  final int visualSize;
  final List<String> aliases;

  // Worker v3.3.x backend truth fields.
  final String currentState;
  final String latestSliceSummary;
  final int sliceCount;
  final int eventCount;
  final int meaningfulUpdateCount;
  final int lastSliceAt;

  const MemoryNodeData({
    required this.id,
    required this.label,
    required this.group,
    required this.level,
    required this.parentId,
    required this.count,
    required this.heat,
    required this.info,
    required this.learned,
    required this.isRoot,
    required this.identityDefining,
    required this.modeScope,
    required this.dateAdded,
    required this.lastMentioned,
    required this.visualSize,
    this.aliases = const <String>[],
    this.currentState = 'active',
    this.latestSliceSummary = '',
    this.sliceCount = 0,
    this.eventCount = 0,
    this.meaningfulUpdateCount = 0,
    this.lastSliceAt = 0,
  });

  factory MemoryNodeData.fromJson(Map<String, dynamic> json, {String backendMode = MemorySession.primaryBackendMode}) {
    int asInt(dynamic v, [int d = 0]) => int.tryParse('${v ?? d}') ?? d;
    return MemoryNodeData(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      group: (json['group'] ?? json['role'] ?? 'interest').toString(),
      level: asInt(json['level'], 4),
      parentId: (json['parentId'] ?? '').toString(),
      count: asInt(json['count'] ?? json['mentionCount']),
      heat: asInt(json['heat']),
      info: (json['info'] ?? json['summary'] ?? '').toString(),
      learned: json['learned'] == true,
      isRoot: json['isRoot'] == true,
      identityDefining: json['identityDefining'] == true,
      modeScope: (json['modeScope'] ?? backendMode).toString(),
      dateAdded: asInt(json['dateAdded'] ?? json['createdAt']),
      lastMentioned: asInt(json['lastMentioned'] ?? json['updatedAt']),
      visualSize: asInt(json['visualSize'], 20),
      aliases: (json['aliases'] is List)
          ? (json['aliases'] as List).map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      currentState: (json['currentState'] ?? json['state'] ?? json['healthState'] ?? 'active').toString(),
      latestSliceSummary: (json['latestSliceSummary'] ?? json['lastSliceSummary'] ?? '').toString(),
      sliceCount: asInt(json['sliceCount'] ?? json['slicesCount']),
      eventCount: asInt(json['eventCount'] ?? json['eventsCount']),
      meaningfulUpdateCount: asInt(json['meaningfulUpdateCount'] ?? json['updateCount']),
      lastSliceAt: asInt(json['lastSliceAt']),
    );
  }
}

class MemoryConnectionData {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String type;
  final int coCount;
  final String reason;
  final String modeScope;
  final int createdAt;
  final int lastUpdated;

  const MemoryConnectionData({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.type,
    required this.coCount,
    required this.reason,
    required this.modeScope,
    required this.createdAt,
    required this.lastUpdated,
  });

  factory MemoryConnectionData.fromJson(Map<String, dynamic> json, {String backendMode = MemorySession.primaryBackendMode}) {
    return MemoryConnectionData(
      id: (json['id'] ?? '').toString(),
      fromNodeId: (json['fromNodeId'] ?? '').toString(),
      toNodeId: (json['toNodeId'] ?? '').toString(),
      type: (json['type'] ?? 'RELATED').toString(),
      coCount: int.tryParse('${json['coCount'] ?? 1}') ?? 1,
      reason: (json['reason'] ?? '').toString(),
      modeScope: (json['modeScope'] ?? backendMode).toString(),
      createdAt: int.tryParse('${json['createdAt'] ?? 0}') ?? 0,
      lastUpdated: int.tryParse('${json['lastUpdated'] ?? 0}') ?? 0,
    );
  }
}

class MemoryGraphPayload {
  final String mode;
  final MemoryProfile profile;
  final List<MemoryNodeData> nodes;
  final List<MemoryConnectionData> connections;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> memoryMeta;
  final bool quotaSafeMode;
  final bool limited;
  final bool hasMore;
  final Map<String, dynamic> limits;
  final bool pass2Deferred;
  final bool debugBudgetExceeded;
  final List<String> optionalWorkSkipped;

  const MemoryGraphPayload({
    required this.mode,
    required this.profile,
    required this.nodes,
    required this.connections,
    required this.stats,
    required this.memoryMeta,
    this.quotaSafeMode = false,
    this.limited = false,
    this.hasMore = false,
    this.limits = const <String, dynamic>{},
    this.pass2Deferred = false,
    this.debugBudgetExceeded = false,
    this.optionalWorkSkipped = const <String>[],
  });

  factory MemoryGraphPayload.fromJson(Map<String, dynamic> json, {String backendMode = MemorySession.primaryBackendMode}) {
    final activeMode = (json['activeMode'] ?? json['mode'] ?? backendMode).toString();
    final quota = (json['quota'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    bool asBool(dynamic v) {
      if (v is bool) return v;
      final s = '$v'.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes';
    }

    List<String> asStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
    }

    return MemoryGraphPayload(
      mode: activeMode,
      profile: MemoryProfile.fromJson(activeMode, (json['profile'] as Map?)?.cast<String, dynamic>()),
      nodes: (json['nodes'] is List)
          ? (json['nodes'] as List)
              .whereType<Map>()
              .map((e) => MemoryNodeData.fromJson(e.cast<String, dynamic>(), backendMode: activeMode))
              .toList(growable: false)
          : const <MemoryNodeData>[],
      connections: ((json['connections'] ?? json['edges']) is List)
          ? ((json['connections'] ?? json['edges']) as List)
              .whereType<Map>()
              .map((e) => MemoryConnectionData.fromJson(e.cast<String, dynamic>(), backendMode: activeMode))
              .toList(growable: false)
          : const <MemoryConnectionData>[],
      stats: (json['stats'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      memoryMeta: (json['memoryMeta'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      quotaSafeMode: asBool(json['quotaSafeMode'] ?? quota['quotaSafeMode']),
      limited: asBool(json['limited'] ?? quota['limited']),
      hasMore: asBool(json['hasMore'] ?? quota['hasMore']),
      limits: (json['limits'] as Map?)?.cast<String, dynamic>() ?? (quota['limits'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      pass2Deferred: asBool(json['pass2Deferred'] ?? quota['pass2Deferred']),
      debugBudgetExceeded: asBool(json['debugBudgetExceeded'] ?? quota['debugBudgetExceeded']),
      optionalWorkSkipped: asStringList(json['optionalWorkSkipped'] ?? quota['optionalWorkSkipped']),
    );
  }
}

class MemorySession {
  static const String primaryBackendMode = GpmaiApiClient.unifiedMemoryMode;
  static const List<String> backendModes = <String>[primaryBackendMode];

  static final ValueNotifier<String> activeModeNotifier = ValueNotifier<String>(primaryBackendMode);
  static final ValueNotifier<bool> busyNotifier = ValueNotifier<bool>(false);

  static MemoryProfile _profile = MemoryProfile.empty(primaryBackendMode);
  static Map<String, dynamic> _memoryMeta = const <String, dynamic>{};
  static bool _initialized = false;

  static String get activeMode => activeModeNotifier.value;
  static Map<String, dynamic> get memoryMeta => _memoryMeta;
  static MemoryProfile get profile => _profile;

  static Future<void> ensureInitialized({bool force = false, String? preferredMode}) async {
    if (_initialized && !force) return;
    busyNotifier.value = true;
    try {
      final init = await GpmaiApiClient.memoryInit(mode: preferredMode ?? activeMode);
      _memoryMeta = (init['memoryMeta'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final nextMode = normalizeMode((init['activeMode'] ?? preferredMode ?? activeMode).toString());
      _profile = MemoryProfile.fromJson(nextMode, (init['profile'] as Map?)?.cast<String, dynamic>());
      activeModeNotifier.value = nextMode;
      _initialized = true;
    } finally {
      busyNotifier.value = false;
    }
  }

  static Future<MemoryProfile> loadProfile({String? mode, bool force = false}) async {
    if (!force && _initialized && _profile.compressedPrompt.isNotEmpty) return _profile;
    final res = await GpmaiApiClient.memoryProfile(mode: mode ?? activeMode);
    _memoryMeta = (res['memoryMeta'] as Map?)?.cast<String, dynamic>() ?? _memoryMeta;
    final nextMode = normalizeMode((res['activeMode'] ?? mode ?? activeMode).toString());
    _profile = MemoryProfile.fromJson(nextMode, (res['profile'] as Map?)?.cast<String, dynamic>());
    activeModeNotifier.value = nextMode;
    _initialized = true;
    return _profile;
  }

  static Future<MemoryProfile> saveProfile(MemoryProfile profile) async {
    busyNotifier.value = true;
    try {
      final res = await GpmaiApiClient.memoryProfileSave(profile.toPayload());
      _memoryMeta = (res['memoryMeta'] as Map?)?.cast<String, dynamic>() ?? _memoryMeta;
      final nextMode = normalizeMode((res['activeMode'] ?? profile.mode).toString());
      final payloadProfile = (res['profile'] as Map?)?.cast<String, dynamic>() ?? profile.toJson();
      _profile = MemoryProfile.fromJson(nextMode, payloadProfile);
      activeModeNotifier.value = nextMode;
      _initialized = true;
      return _profile;
    } finally {
      busyNotifier.value = false;
    }
  }

  static Future<void> setActiveMode(String mode) async {
    final res = await GpmaiApiClient.memorySetActiveMode(mode: mode);
    final nextMode = normalizeMode((res['activeMode'] ?? mode).toString());
    activeModeNotifier.value = nextMode;
    if (res['profile'] is Map) {
      _profile = MemoryProfile.fromJson(nextMode, (res['profile'] as Map).cast<String, dynamic>());
    }
    if (res['memoryMeta'] is Map) {
      _memoryMeta = (res['memoryMeta'] as Map).cast<String, dynamic>();
    }
    _initialized = true;
  }

  static Future<MemoryGraphPayload> loadGraph([String? mode]) async {
    const int nodeLimit = 50;
    const int edgeLimit = 80;
    const int eventLimit = 30;
    const int candidateLimit = 30;
    const bool includeDebug = false;
    await ensureInitialized(preferredMode: mode);
    final res = await GpmaiApiClient.memoryGraph(
      mode: mode ?? activeMode,
      nodeLimit: nodeLimit,
      edgeLimit: edgeLimit,
      eventLimit: eventLimit,
      candidateLimit: candidateLimit,
      includeDebug: includeDebug,
    );
    _memoryMeta = (res['memoryMeta'] as Map?)?.cast<String, dynamic>() ?? _memoryMeta;
    final payload = MemoryGraphPayload.fromJson(res, backendMode: activeMode);
    final profile = payload.profile.compressedPrompt.trim().isNotEmpty
        ? payload.profile
        : payload.profile.copyWith(compressedPrompt: _buildCompressedPreview(payload.profile));
    _profile = profile;
    activeModeNotifier.value = payload.mode;
    return MemoryGraphPayload(
      mode: payload.mode,
      profile: profile,
      nodes: payload.nodes,
      connections: payload.connections,
      stats: payload.stats,
      memoryMeta: payload.memoryMeta,
      quotaSafeMode: payload.quotaSafeMode,
      limited: payload.limited,
      hasMore: payload.hasMore,
      limits: payload.limits,
      pass2Deferred: payload.pass2Deferred,
      debugBudgetExceeded: payload.debugBudgetExceeded,
      optionalWorkSkipped: payload.optionalWorkSkipped,
    );
  }

  static Future<Map<String, dynamic>> debugStatus({
    int logLimit = 20,
    int jobLimit = 20,
    int candidateLimit = 30,
    int eventLimit = 30,
  }) {
    return GpmaiApiClient.memoryDebugStatus(
      logLimit: logLimit,
      jobLimit: jobLimit,
      candidateLimit: candidateLimit,
      eventLimit: eventLimit,
    );
  }

  static Future<Map<String, dynamic>> debugFull({bool full = false}) {
    return GpmaiApiClient.memoryDebugFull(full: full);
  }

  static Future<Map<String, dynamic>> deleteNode(MemoryNodeData node) {
    return GpmaiApiClient.memoryDeleteNode(nodeId: node.id, mode: node.modeScope.isEmpty ? activeMode : node.modeScope);
  }

  static Future<Map<String, dynamic>> simulateLearn() {
    return GpmaiApiClient.memorySimulateLearn(mode: activeMode);
  }

  static Future<Map<String, dynamic>> chatPreview({String? question}) {
    return GpmaiApiClient.memoryChatPreview(mode: activeMode, question: question);
  }

  static Future<Map<String, dynamic>> recallPreview({
    required String question,
    String sourceTag = 'chat',
    String? chatId,
  }) {
    return GpmaiApiClient.memoryRecallPreview(
      mode: activeMode,
      messages: _singleUserMessage(question),
      sourceTag: sourceTag,
      threadId: chatId,
      chatId: chatId,
      conversationId: chatId,
    );
  }

  static Future<Map<String, dynamic>> writePreview({
    required String userText,
    String assistantText = '',
    String sourceTag = 'chat',
  }) {
    return GpmaiApiClient.memoryWritePreview(
      mode: activeMode,
      messages: _singleUserMessage(userText),
      assistantText: assistantText,
      sourceTag: sourceTag,
    );
  }


  static Future<Map<String, dynamic>> learnFlush({
    required String userText,
    String assistantText = '',
    String sourceTag = 'chat',
    String? threadId,
    bool forceExtract = true,
  }) {
    final resolvedThreadId = (threadId == null || threadId.trim().isEmpty) ? 'manual_debug_thread' : threadId.trim();
    return GpmaiApiClient.memoryLearnFlush(
      mode: activeMode,
      messages: _singleUserMessage(userText),
      assistantText: assistantText,
      sourceTag: sourceTag,
      threadId: resolvedThreadId,
      chatId: resolvedThreadId,
      conversationId: resolvedThreadId,
      forceExtract: forceExtract,
    );
  }

  static Future<Map<String, dynamic>> finalStatus({bool full = false}) {
    return GpmaiApiClient.memoryFinalStatus(full: full);
  }

  static Future<Map<String, dynamic>> consolidationStatus() {
    return GpmaiApiClient.memoryConsolidationStatus();
  }

  static Future<Map<String, dynamic>> runConsolidation({bool dryRun = true}) {
    return GpmaiApiClient.memoryConsolidationRun(dryRun: dryRun);
  }

  static Future<Map<String, dynamic>> runMaintenance() {
    return GpmaiApiClient.memoryMaintenanceRun();
  }

  static Future<Map<String, dynamic>> resetLearned() {
    return GpmaiApiClient.memoryResetLearned();
  }

  static Future<Map<String, dynamic>> importSyntheticDatedHistory({
    bool resetLearned = false,
    int chunkSize = 1,
  }) {
    return importDatedHistoryEntries(
      entries: _buildSyntheticHistoryEntries(),
      resetLearned: resetLearned,
      chunkSize: chunkSize,
    );
  }

  static Future<Map<String, dynamic>> importDatedHistoryEntries({
    required List<Map<String, dynamic>> entries,
    bool resetLearned = false,
    int chunkSize = 1,
  }) async {
    if (entries.isEmpty) {
      return <String, dynamic>{
        'ok': false,
        'error': 'No dated history entries were provided.',
      };
    }

    if (resetLearned) {
      await GpmaiApiClient.memoryResetLearned();
    }

    final safeChunk = chunkSize < 1 ? 1 : chunkSize;
    var totalImported = 0;
    Map<String, dynamic> last = const <String, dynamic>{};

    for (var i = 0; i < entries.length; i += safeChunk) {
      final batch = entries.sublist(i, (i + safeChunk) > entries.length ? entries.length : i + safeChunk);
      final res = await GpmaiApiClient.memoryImportDatedHistory(
        entries: batch,
        resetLearned: false,
      );
      last = res;
      totalImported += int.tryParse('${res['importedEntries'] ?? batch.length}') ?? batch.length;
    }

    return <String, dynamic>{
      ...last,
      'ok': true,
      'importedEntries': totalImported,
      'chunkSize': safeChunk,
      'batches': ((entries.length + safeChunk - 1) ~/ safeChunk),
    };
  }

  static Future<Map<String, dynamic>> importCurrentLocalHistory({
    bool resetLearned = false,
    int maxChats = 18,
    int chunkSize = 2,
    int maxMessagesPerChat = 12,
  }) {
    return bootstrapFromLocalHistory(
      resetLearned: resetLearned,
      maxChats: maxChats,
      chunkSize: chunkSize,
      maxMessagesPerChat: maxMessagesPerChat,
    );
  }

  static Future<Map<String, dynamic>> bootstrapFromLocalHistory({
    bool resetLearned = false,
    int maxChats = 18,
    int chunkSize = 2,
    int maxMessagesPerChat = 12,
  }) async {
    final store = SqlChatStore();
    final chats = await store.watchChats().first;
    final entries = <Map<String, dynamic>>[];

    for (final chat in chats) {
      final messages = await store.getMessages(chat.id);
      if (messages.length < 2) continue;

      var hasUser = false;
      var hasAssistant = false;
      final tail = messages.length > maxMessagesPerChat
          ? messages.sublist(messages.length - maxMessagesPerChat)
          : messages;

      final lines = <String>[];
      String snippet = '';
      for (final msg in tail) {
        final role = msg.role.trim().toLowerCase();
        final text = msg.text.trim();
        if (text.isEmpty) continue;
        if (role == 'user') {
          hasUser = true;
          snippet = snippet.isEmpty ? _trimBootstrapText(text, 220) : snippet;
        }
        if (_isAssistantRole(role)) hasAssistant = true;
        lines.add('${_displayRole(role)}: ${_trimBootstrapText(text, 340)}');
      }

      if (!hasUser || !hasAssistant || lines.length < 2) continue;

      entries.add({
        'title': chat.name,
        'sourceTag': _sourceTagForBootstrap(chat.presetJson),
        'snippet': snippet,
        'text': lines.join('\n'),
      });

      if (entries.length >= maxChats) break;
    }

    if (entries.isEmpty) {
      return {
        'ok': false,
        'error': 'No meaningful local chats were found for memory bootstrap yet.',
      };
    }

    var totalImported = 0;
    var totalCreated = 0;
    var totalIncremented = 0;
    Map<String, dynamic> last = const <String, dynamic>{};

    for (var i = 0; i < entries.length; i += chunkSize) {
      final batch = entries.sublist(i, i + chunkSize > entries.length ? entries.length : i + chunkSize);
      final res = await GpmaiApiClient.memoryBootstrap(
        mode: activeMode,
        entries: batch,
        resetLearned: resetLearned && i == 0,
      );
      last = res;
      totalImported += int.tryParse('${res['importedEntries'] ?? batch.length}') ?? batch.length;
      totalCreated += int.tryParse('${res['createdNodesApprox'] ?? res['createdNodes'] ?? 0}') ?? 0;
      totalIncremented += int.tryParse('${res['incrementedCount'] ?? res['incrementedNodes'] ?? 0}') ?? 0;
    }

    return {
      ...last,
      'ok': true,
      'importedEntries': totalImported,
      'createdNodesApprox': totalCreated,
      'incrementedCount': totalIncremented,
      'source': 'local_history',
    };
  }

  static String _buildCompressedPreview(MemoryProfile profile) {
    final lines = <String>[];
    if (profile.name.trim().isNotEmpty) lines.add('Name: ${profile.name.trim()}');
    if (profile.role.trim().isNotEmpty) lines.add('Current focus: ${profile.role.trim()}');
    if (profile.projects.trim().isNotEmpty) lines.add('Projects: ${profile.projects.trim()}');
    if (profile.stack.trim().isNotEmpty) lines.add('Tech stack: ${profile.stack.trim()}');
    if (profile.goals.trim().isNotEmpty) lines.add('Goals: ${profile.goals.trim()}');
    if (profile.style.trim().isNotEmpty) lines.add('Response preferences: ${profile.style.trim()}');
    return lines.join('\n');
  }

  static bool _isAssistantRole(String role) {
    return role == 'assistant' || role == 'gpm' || role == 'bot' || role == 'ai';
  }

  static String _displayRole(String role) {
    if (role == 'user') return 'USER';
    if (_isAssistantRole(role)) return 'ASSISTANT';
    return role.toUpperCase();
  }

  static String _trimBootstrapText(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max - 1)}â€¦';
  }

  static String _sourceTagForBootstrap(String? presetJson) {
    final raw = (presetJson ?? '').trim();
    if (raw.isEmpty) return 'chat';
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final kind = (map['kind'] ?? '').toString().trim().toLowerCase();
        if (kind == 'tool') return 'chat';
        if (kind == 'persona' || kind == 'bot') return 'chat';
        if (kind.isNotEmpty) return kind;
      }
    } catch (_) {}
    return 'chat';
  }

  static List<Map<String, dynamic>> _singleUserMessage(String text) => <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': text.trim(),
        }
      ];

  static List<Map<String, dynamic>> _buildSyntheticHistoryEntries() {
    final now = DateTime.now();
    int ts(DateTime dt) => dt.millisecondsSinceEpoch;

    return <Map<String, dynamic>>[
      {
        'timestamp': ts(now.subtract(const Duration(days: 120))),
        'threadId': 'identity_role_foundation',
        'sourceTag': 'chat',
        'messages': _singleUserMessage('My name is Sziyuu. I build apps mainly with Flutter and I want simple practical help.'),
        'assistantText': 'Locked. I will treat you as a Flutter-first app builder who prefers practical and simple guidance.',
      },
      {
        'timestamp': ts(now.subtract(const Duration(days: 108))),
        'threadId': 'gpmai_vision',
        'sourceTag': 'chat',
        'messages': _singleUserMessage('I am building GPMai as a serious AI product, not a toy wrapper.'),
        'assistantText': 'Understood. The product direction is production-grade, serious and long-term.',
      },
      {
        'timestamp': ts(now.subtract(const Duration(days: 96))),
        'threadId': 'gpmai_stack',
        'sourceTag': 'chat',
        'messages': _singleUserMessage('The main stack is Flutter, Firebase, Cloudflare Workers and OpenRouter.'),
        'assistantText': 'That stack gives a clear split between app UI, backend orchestration and persisted state.',
      },
      {
        'timestamp': ts(now.subtract(const Duration(days: 82))),
        'threadId': 'gpmai_memory_architecture',
        'sourceTag': 'chat',
        'messages': _singleUserMessage('I want nodes, events and evidence properly separated in the memory brain.'),
        'assistantText': 'Good call. Nodes should stay conceptual while events hold incidents and evidence keeps proof.',
      },
      {
        'timestamp': ts(now.subtract(const Duration(days: 68))),
        'threadId': 'gpmai_recall_engine',
        'sourceTag': 'chat',
        'messages': _singleUserMessage('The recall engine should detect triggers, activate clusters and inject bounded memory only.'),
        'assistantText': 'Perfect. That keeps recall useful without bloating every chat turn.',
      },
      {
        'timestamp': ts(now.subtract(const Duration(days: 45))),
        'threadId': 'gpmai_launch_goal',
        'sourceTag': 'chat',
        'messages': _singleUserMessage('One of my main goals is to launch GPMai on the Play Store in a serious way.'),
        'assistantText': 'That makes Play Store launch a strong active goal for the graph.',
      },
      {
        'timestamp': ts(now.subtract(const Duration(days: 20))),
        'threadId': 'response_preference_loop',
        'sourceTag': 'chat',
        'messages': _singleUserMessage('Do not give fluffy responses. I want strong practical ideas and serious product thinking.'),
        'assistantText': 'Got it. I will keep the style direct, practical and product-focused.',
      },
      {
        'timestamp': ts(now.subtract(const Duration(days: 7))),
        'threadId': 'current_focus_pipeline',
        'sourceTag': 'chat',
        'messages': _singleUserMessage('Right now my main focus is the GPMai memory brain, pipeline rebuild and premium memory UI.'),
        'assistantText': 'Nice. That gives the graph a clear current focus around memory architecture, rebuild flow and premium UI.',
      },
    ];
  }

  static String normalizeMode(String mode) {
    final clean = mode.trim().toLowerCase();
    return clean.isEmpty ? primaryBackendMode : clean;
  }

  static String modeLabel(String mode) => 'Unified';
}

