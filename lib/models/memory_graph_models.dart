class MemoryGraphResponse {
  final bool ok;
  final String uid;
  final Map<String, dynamic> stats;
  final List<MemoryNodeVm> nodes;
  final List<MemoryEdgeVm> connections;
  final Map<String, dynamic> memoryMeta;

  /// Quota-safe backend fields added in Worker v3.3.x.
  final bool quotaSafeMode;
  final bool limited;
  final bool hasMore;
  final Map<String, dynamic> limits;
  final bool pass2Deferred;
  final bool debugBudgetExceeded;
  final List<String> optionalWorkSkipped;
  final List<MemoryEventVm> events;
  final List<MemorySliceVm> recentSlices;
  final List<MemoryCandidateVm> candidates;

  MemoryGraphResponse({
    required this.ok,
    required this.uid,
    required this.stats,
    required this.nodes,
    required this.connections,
    required this.memoryMeta,
    this.quotaSafeMode = false,
    this.limited = false,
    this.hasMore = false,
    this.limits = const <String, dynamic>{},
    this.pass2Deferred = false,
    this.debugBudgetExceeded = false,
    this.optionalWorkSkipped = const <String>[],
    this.events = const <MemoryEventVm>[],
    this.recentSlices = const <MemorySliceVm>[],
    this.candidates = const <MemoryCandidateVm>[],
  });

  factory MemoryGraphResponse.fromJson(Map<String, dynamic> json) {
    final quota = _readQuotaInfo(json);
    final eventRaw = _readFirstList(json, const [
      'events',
      'recentEvents',
      'recentEventPreview',
      'eventPreview',
    ]);
    final sliceRaw = _readFirstList(json, const [
      'recentSlices',
      'slices',
      'slicePreview',
      'nodeSlicePreview',
    ]);
    final candidateRaw = _readFirstList(json, const [
      'candidates',
      'candidatePreview',
      'recentCandidates',
    ]);
    return MemoryGraphResponse(
      ok: json['ok'] == true,
      uid: (json['uid'] ?? '').toString(),
      stats: _readMap(json['stats']),
      nodes: _readList(json['nodes'])
          .map((e) => MemoryNodeVm.fromJson(e))
          .toList(growable: false),
      connections: _readList(json['connections'] ?? json['edges'])
          .map((e) => MemoryEdgeVm.fromJson(e))
          .toList(growable: false),
      memoryMeta: _readMap(json['memoryMeta']),
      quotaSafeMode: _readBool(json['quotaSafeMode'] ?? quota['quotaSafeMode'] ?? json['quotaSafe']),
      limited: _readBool(json['limited'] ?? quota['limited']),
      hasMore: _readBool(json['hasMore'] ?? quota['hasMore']),
      limits: _readMap(json['limits'] ?? quota['limits']),
      pass2Deferred: _readBool(json['pass2Deferred'] ?? quota['pass2Deferred']),
      debugBudgetExceeded: _readBool(json['debugBudgetExceeded'] ?? quota['debugBudgetExceeded']),
      optionalWorkSkipped: _readStringList(json['optionalWorkSkipped'] ?? quota['optionalWorkSkipped']),
      events: eventRaw.map((e) => MemoryEventVm.fromJson(e)).toList(growable: false),
      recentSlices: sliceRaw.map((e) => MemorySliceVm.fromJson(e)).toList(growable: false),
      candidates: candidateRaw.map((e) => MemoryCandidateVm.fromJson(e)).toList(growable: false),
    );
  }
}

class MemoryNodeVm {
  final String id;
  final String label;
  final String group;
  final String cluster;
  final String healthState;
  final String currentState;
  final String importanceClass;
  final int count;
  final int heat;
  final double visualSize;
  final bool isRoot;
  final String? info;
  final int eventCount;
  final int sliceCount;
  final int meaningfulUpdateCount;
  final int? lastMentioned;
  final int? lastSliceAt;
  final String? latestSliceSummary;
  final String? lastSliceId;
  final String? lastEventSummary;
  final String? lifecycleAction;

  MemoryNodeVm({
    required this.id,
    required this.label,
    required this.group,
    required this.cluster,
    required this.healthState,
    required this.currentState,
    required this.importanceClass,
    required this.count,
    required this.heat,
    required this.visualSize,
    required this.isRoot,
    required this.info,
    required this.eventCount,
    required this.sliceCount,
    required this.meaningfulUpdateCount,
    required this.lastMentioned,
    this.lastSliceAt,
    this.latestSliceSummary,
    this.lastSliceId,
    this.lastEventSummary,
    this.lifecycleAction,
  });

  factory MemoryNodeVm.fromJson(Map<String, dynamic> json) {
    final currentState = (json['currentState'] ?? json['state'] ?? json['healthState'] ?? 'active').toString();
    return MemoryNodeVm(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      group: (json['group'] ?? json['role'] ?? json['nodeRole'] ?? 'interest').toString(),
      cluster: (json['cluster'] ?? json['clusterId'] ?? json['resolvedClusterId'] ?? 'general').toString(),
      healthState: currentState,
      currentState: currentState,
      importanceClass: (json['importanceClass'] ?? json['importance'] ?? 'ordinary').toString(),
      count: _readNum(json['count'] ?? json['mentionCount']).toInt(),
      heat: _readNum(json['heat']).toInt(),
      visualSize: _readNum(json['visualSize'], 24).toDouble(),
      isRoot: json['isRoot'] == true,
      info: _readNullableString(json['info'] ?? json['summary'] ?? json['nodeSummary']),
      eventCount: _readNum(json['eventCount'] ?? json['eventsCount']).toInt(),
      sliceCount: _readNum(json['sliceCount'] ?? json['slicesCount']).toInt(),
      meaningfulUpdateCount: _readNum(json['meaningfulUpdateCount'] ?? json['updateCount']).toInt(),
      lastMentioned: json['lastMentioned'] == null ? null : _readNum(json['lastMentioned']).toInt(),
      lastSliceAt: json['lastSliceAt'] == null ? null : _readNum(json['lastSliceAt']).toInt(),
      latestSliceSummary: _readNullableString(json['latestSliceSummary'] ?? json['lastSliceSummary']),
      lastSliceId: _readNullableString(json['lastSliceId']),
      lastEventSummary: _readNullableString(json['lastEventSummary'] ?? json['latestEventSummary']),
      lifecycleAction: _readNullableString(json['lifecycleAction'] ?? json['lastLifecycleAction']),
    );
  }
}

class MemoryEdgeVm {
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String type;
  final int coCount;
  final String? reason;

  MemoryEdgeVm({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.type,
    required this.coCount,
    required this.reason,
  });

  factory MemoryEdgeVm.fromJson(Map<String, dynamic> json) {
    return MemoryEdgeVm(
      id: (json['id'] ?? '').toString(),
      fromNodeId: (json['fromNodeId'] ?? json['from'] ?? '').toString(),
      toNodeId: (json['toNodeId'] ?? json['to'] ?? '').toString(),
      type: (json['type'] ?? 'related_to').toString(),
      coCount: _readNum(json['coCount'] ?? json['weight'] ?? json['reinforcementCount'], 1).toInt(),
      reason: _readNullableString(json['reason'] ?? json['summary']),
    );
  }
}

class MemoryEventVm {
  final String id;
  final String primaryNodeId;
  final String primaryNodeLabel;
  final String eventType;
  final String lifecycleAction;
  final String summary;
  final String status;
  final int createdAt;
  final int updatedAt;

  const MemoryEventVm({
    required this.id,
    required this.primaryNodeId,
    required this.primaryNodeLabel,
    required this.eventType,
    required this.lifecycleAction,
    required this.summary,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoryEventVm.fromJson(Map<String, dynamic> json) {
    return MemoryEventVm(
      id: (json['id'] ?? json['eventId'] ?? '').toString(),
      primaryNodeId: (json['primaryNodeId'] ?? json['nodeId'] ?? '').toString(),
      primaryNodeLabel: (json['primaryNodeLabel'] ?? json['nodeLabel'] ?? '').toString(),
      eventType: (json['eventType'] ?? json['type'] ?? '').toString(),
      lifecycleAction: (json['lifecycleAction'] ?? json['action'] ?? '').toString(),
      summary: (json['summary'] ?? json['text'] ?? json['title'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: _readNum(json['createdAt'] ?? json['startAt']).toInt(),
      updatedAt: _readNum(json['updatedAt'] ?? json['endAt'] ?? json['createdAt']).toInt(),
    );
  }
}

class MemorySliceVm {
  final String id;
  final String nodeId;
  final String nodeLabel;
  final String summaryDraft;
  final String narrativeSummary;
  final String kind;
  final int createdAt;

  const MemorySliceVm({
    required this.id,
    required this.nodeId,
    required this.nodeLabel,
    required this.summaryDraft,
    required this.narrativeSummary,
    required this.kind,
    required this.createdAt,
  });

  factory MemorySliceVm.fromJson(Map<String, dynamic> json) {
    return MemorySliceVm(
      id: (json['id'] ?? json['sliceId'] ?? '').toString(),
      nodeId: (json['nodeId'] ?? '').toString(),
      nodeLabel: (json['nodeLabel'] ?? '').toString(),
      summaryDraft: (json['summaryDraft'] ?? json['summary'] ?? '').toString(),
      narrativeSummary: (json['narrativeSummary'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      createdAt: _readNum(json['createdAt']).toInt(),
    );
  }
}

class MemoryCandidateVm {
  final String id;
  final String label;
  final String status;
  final String strength;
  final int mentionCount;
  final int expiresAt;
  final List<Map<String, dynamic>> evidence;

  const MemoryCandidateVm({
    required this.id,
    required this.label,
    required this.status,
    required this.strength,
    required this.mentionCount,
    required this.expiresAt,
    required this.evidence,
  });

  factory MemoryCandidateVm.fromJson(Map<String, dynamic> json) {
    return MemoryCandidateVm(
      id: (json['id'] ?? json['candidateId'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      strength: (json['strength'] ?? '').toString(),
      mentionCount: _readNum(json['mentionCount']).toInt(),
      expiresAt: _readNum(json['expiresAt']).toInt(),
      evidence: _readList(json['evidence']),
    );
  }
}

Map<String, dynamic> _readMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.cast<String, dynamic>();
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _readList(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(growable: false);
}

List<Map<String, dynamic>> _readFirstList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final list = _readList(json[key]);
    if (list.isNotEmpty) return list;
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _readQuotaInfo(Map<String, dynamic> json) {
  final direct = _readMap(json['quota']);
  if (direct.isNotEmpty) return direct;
  final summary = _readMap(json['quotaSummary']);
  if (summary.isNotEmpty) return summary;
  return const <String, dynamic>{};
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
}

num _readNum(dynamic v, [num d = 0]) => v is num ? v : num.tryParse('$v') ?? d;

bool _readBool(dynamic v) {
  if (v is bool) return v;
  final s = '$v'.toLowerCase().trim();
  return s == 'true' || s == '1' || s == 'yes';
}

String? _readNullableString(dynamic v) {
  final text = v?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
