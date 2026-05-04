import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DebateRoomParticipant {
  final String modelId;
  final String displayName;
  final String provider;

  const DebateRoomParticipant({
    required this.modelId,
    required this.displayName,
    required this.provider,
  });

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'displayName': displayName,
        'provider': provider,
      };

  factory DebateRoomParticipant.fromJson(Map<String, dynamic> json) {
    return DebateRoomParticipant(
      modelId: (json['modelId'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
    );
  }
}

class DebateRoomEvent {
  final String id;
  final int round;
  final String stage;
  final String type;
  final String? modelId;
  final String? provider;
  final String? modelName;
  final String content;
  final DateTime createdAt;

  const DebateRoomEvent({
    required this.id,
    required this.round,
    required this.stage,
    required this.type,
    required this.content,
    required this.createdAt,
    this.modelId,
    this.provider,
    this.modelName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'round': round,
        'stage': stage,
        'type': type,
        'modelId': modelId,
        'provider': provider,
        'modelName': modelName,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DebateRoomEvent.fromJson(Map<String, dynamic> json) {
    return DebateRoomEvent(
      id: (json['id'] ?? '').toString(),
      round: int.tryParse((json['round'] ?? '0').toString()) ?? 0,
      stage: (json['stage'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      modelId: json['modelId']?.toString(),
      provider: json['provider']?.toString(),
      modelName: json['modelName']?.toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class DebateRoomSession {
  final String id;
  final String title;
  final String question;
  final String goal;
  final String outputStyle;
  final String depth;
  final String? contextNote;
  final List<DebateRoomParticipant> participants;
  final List<DebateRoomEvent> events;
  final String status;
  final String? activeStage;
  final String? activeModelId;
  final String? finalSummary;
  final bool pinned;
  final bool liveWindowOpen;
  final DateTime? liveEndsAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DebateRoomSession({
    required this.id,
    required this.title,
    required this.question,
    required this.goal,
    required this.outputStyle,
    required this.depth,
    required this.participants,
    required this.events,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.contextNote,
    this.activeStage,
    this.activeModelId,
    this.finalSummary,
    this.pinned = false,
    this.liveWindowOpen = false,
    this.liveEndsAt,
  });

  DebateRoomSession copyWith({
    String? id,
    String? title,
    String? question,
    String? goal,
    String? outputStyle,
    String? depth,
    String? contextNote,
    List<DebateRoomParticipant>? participants,
    List<DebateRoomEvent>? events,
    String? status,
    String? activeStage,
    String? activeModelId,
    String? finalSummary,
    bool? pinned,
    bool? liveWindowOpen,
    DateTime? liveEndsAt,
    bool clearLiveEndsAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DebateRoomSession(
      id: id ?? this.id,
      title: title ?? this.title,
      question: question ?? this.question,
      goal: goal ?? this.goal,
      outputStyle: outputStyle ?? this.outputStyle,
      depth: depth ?? this.depth,
      contextNote: contextNote ?? this.contextNote,
      participants: participants ?? this.participants,
      events: events ?? this.events,
      status: status ?? this.status,
      activeStage: activeStage ?? this.activeStage,
      activeModelId: activeModelId ?? this.activeModelId,
      finalSummary: finalSummary ?? this.finalSummary,
      pinned: pinned ?? this.pinned,
      liveWindowOpen: liveWindowOpen ?? this.liveWindowOpen,
      liveEndsAt: clearLiveEndsAt ? null : (liveEndsAt ?? this.liveEndsAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'question': question,
        'goal': goal,
        'outputStyle': outputStyle,
        'depth': depth,
        'contextNote': contextNote,
        'participants': participants.map((e) => e.toJson()).toList(growable: false),
        'events': events.map((e) => e.toJson()).toList(growable: false),
        'status': status,
        'activeStage': activeStage,
        'activeModelId': activeModelId,
        'finalSummary': finalSummary,
        'pinned': pinned,
        'liveWindowOpen': liveWindowOpen,
        'liveEndsAt': liveEndsAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory DebateRoomSession.fromJson(Map<String, dynamic> json) {
    final participantsRaw = json['participants'];
    final eventsRaw = json['events'];
    return DebateRoomSession(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      goal: (json['goal'] ?? '').toString(),
      outputStyle: (json['outputStyle'] ?? '').toString(),
      depth: (json['depth'] ?? '').toString(),
      contextNote: json['contextNote']?.toString(),
      participants: participantsRaw is List
          ? participantsRaw
              .whereType<Map>()
              .map((e) => DebateRoomParticipant.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const <DebateRoomParticipant>[],
      events: eventsRaw is List
          ? eventsRaw
              .whereType<Map>()
              .map((e) => DebateRoomEvent.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
          : const <DebateRoomEvent>[],
      status: (json['status'] ?? 'draft').toString(),
      activeStage: json['activeStage']?.toString(),
      activeModelId: json['activeModelId']?.toString(),
      finalSummary: json['finalSummary']?.toString(),
      pinned: json['pinned'] == true,
      liveWindowOpen: json['liveWindowOpen'] == true,
      liveEndsAt: DateTime.tryParse((json['liveEndsAt'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class DebateRoomStore {
  static const String _key = 'gpmai_debate_room_sessions_v1';

  Future<List<DebateRoomSession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final items = <DebateRoomSession>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          items.add(DebateRoomSession.fromJson(decoded));
        } else if (decoded is Map) {
          items.add(DebateRoomSession.fromJson(decoded.cast<String, dynamic>()));
        }
      } catch (_) {}
    }
    items.sort(_sortSessions);
    return items;
  }

  Future<DebateRoomSession?> getById(String id) async {
    final all = await loadAll();
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> upsert(DebateRoomSession session) async {
    final all = await loadAll();
    final next = <DebateRoomSession>[];
    var found = false;
    for (final item in all) {
      if (item.id == session.id) {
        next.add(session.copyWith(updatedAt: DateTime.now()));
        found = true;
      } else {
        next.add(item);
      }
    }
    if (!found) {
      next.add(session.copyWith(updatedAt: DateTime.now()));
    }
    await _save(next);
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    await _save(all.where((e) => e.id != id).toList(growable: false));
  }

  Future<void> rename(String id, String title) async {
    final all = await loadAll();
    final next = all
        .map((e) => e.id == id ? e.copyWith(title: title.trim(), updatedAt: DateTime.now()) : e)
        .toList(growable: false);
    await _save(next);
  }

  Future<void> togglePinned(String id) async {
    final all = await loadAll();
    final next = all
        .map((e) => e.id == id ? e.copyWith(pinned: !e.pinned, updatedAt: DateTime.now()) : e)
        .toList(growable: false);
    await _save(next);
  }

  Future<void> _save(List<DebateRoomSession> items) async {
    final prefs = await SharedPreferences.getInstance();
    items.sort(_sortSessions);
    final raw = items.map((e) => jsonEncode(e.toJson())).toList(growable: false);
    await prefs.setStringList(_key, raw);
  }

  static int _sortSessions(DebateRoomSession a, DebateRoomSession b) {
    if (a.pinned != b.pinned) return b.pinned ? 1 : -1;
    return b.updatedAt.compareTo(a.updatedAt);
  }
}
