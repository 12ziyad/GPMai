import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomPersona {
  final String id;
  final String name;
  final String description;
  final String behaviorPrompt;
  final String greeting;
  final String? emoji;
  final int accentValue;
  final int? iconCodePoint;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;

  const CustomPersona({
    required this.id,
    required this.name,
    required this.description,
    required this.behaviorPrompt,
    required this.greeting,
    required this.accentValue,
    required this.createdAt,
    required this.updatedAt,
    this.emoji,
    this.iconCodePoint,
    this.pinned = false,
  });

  IconData? get icon => iconCodePoint == null ? null : IconData(iconCodePoint!, fontFamily: 'MaterialIcons');
  Color get accent => Color(accentValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'behaviorPrompt': behaviorPrompt,
        'greeting': greeting,
        'emoji': emoji,
        'accentValue': accentValue,
        'iconCodePoint': iconCodePoint,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pinned': pinned,
      };

  factory CustomPersona.fromJson(Map<String, dynamic> json) => CustomPersona(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        behaviorPrompt: json['behaviorPrompt'] as String? ?? '',
        greeting: json['greeting'] as String? ?? '',
        emoji: json['emoji'] as String?,
        accentValue: (json['accentValue'] as num?)?.toInt() ?? 0xFF7E57C2,
        iconCodePoint: (json['iconCodePoint'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        pinned: json['pinned'] as bool? ?? false,
      );
}

class CustomPersonasService {
  static const _kStore = 'custom_personas_v1';

  static Future<List<CustomPersona>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStore);
    if (raw == null || raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => CustomPersona.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Future<void> save(CustomPersona persona) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await all();
    final next = [...list.where((e) => e.id != persona.id), persona]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(_kStore, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await all();
    final next = list.where((e) => e.id != id).toList();
    await prefs.setString(_kStore, jsonEncode(next.map((e) => e.toJson()).toList()));
  }

  static Future<void> togglePinned(String id) async {
    final list = await all();
    final next = list
        .map((e) => e.id == id
            ? CustomPersona(
                id: e.id,
                name: e.name,
                description: e.description,
                behaviorPrompt: e.behaviorPrompt,
                greeting: e.greeting,
                emoji: e.emoji,
                accentValue: e.accentValue,
                iconCodePoint: e.iconCodePoint,
                createdAt: e.createdAt,
                updatedAt: DateTime.now(),
                pinned: !e.pinned,
              )
            : e)
        .toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStore, jsonEncode(next.map((e) => e.toJson()).toList()));
  }
}
