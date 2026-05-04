// lib/services/sql_chat_store.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'sql_chat_store.g.dart';

class Chats extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant('New Chat'))();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  IntColumn get lastAt => integer()();
  TextColumn get presetJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Message')
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get chatId => text()();
  TextColumn get role => text()();
  TextColumn get text_ => text().named('text')();
  IntColumn get ts => integer()();
}

@DriftDatabase(tables: [Chats, ChatMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static AppDatabase? _instance;
  static AppDatabase get I => _instance ??= AppDatabase();

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            try {
              await m.addColumn(chats, chats.presetJson);
            } catch (_) {}

            await customStatement('''
              CREATE TABLE IF NOT EXISTS chat_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chat_id TEXT NOT NULL,
                role TEXT NOT NULL,
                text TEXT NOT NULL,
                ts INTEGER NOT NULL
              );
            ''');
          }

          if (from < 3) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS chats (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL DEFAULT 'New Chat',
                starred INTEGER NOT NULL DEFAULT 0,
                lastAt INTEGER NOT NULL,
                presetJson TEXT
              );
            ''');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'gpmai.db'));
    return NativeDatabase(file, logStatements: true);
  });
}

extension MessageX on Message {
  String get text => text_;
}

class SqlChatStore {
  final AppDatabase db = AppDatabase.I;

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<String> createChat({String? name, Map<String, dynamic>? preset}) async {
    final id = _newId();
    try {
      await db.into(db.chats).insert(
            ChatsCompanion.insert(
              id: id,
              name: Value(name ?? 'New Chat'),
              lastAt: DateTime.now().millisecondsSinceEpoch,
              presetJson: Value(preset == null ? null : jsonEncode(preset)),
            ),
          );
      return id;
    } catch (e, st) {
      // ignore: avoid_print
      print('createChat failed → $e\n$st');
      rethrow;
    }
  }

  Stream<List<Chat>> watchChats({bool starredOnly = false}) {
    final q = db.select(db.chats)..orderBy([(t) => OrderingTerm.desc(t.lastAt)]);
    if (starredOnly) q.where((t) => t.starred.equals(true));
    return q.watch().asyncMap(_filterHistoryVisibleChats);
  }

  Future<List<Chat>> _filterHistoryVisibleChats(List<Chat> chats) async {
    if (chats.isEmpty) return const <Chat>[];

    final allMessages = await (db.select(db.chatMessages)).get();
    final userSeen = <String>{};
    final aiSeen = <String>{};

    for (final msg in allMessages) {
      final role = msg.role.trim().toLowerCase();
      if (role == 'user') {
        userSeen.add(msg.chatId);
      } else if (role == 'gpm' || role == 'assistant' || role == 'bot' || role == 'ai') {
        aiSeen.add(msg.chatId);
      }
    }

    final eligible = userSeen.intersection(aiSeen);
    return chats.where((chat) => eligible.contains(chat.id)).toList(growable: false);
  }

  Stream<List<Chat>> watchLast5ForFolder({
    required String spaceId,
    required String folderId,
  }) {
    return watchChats().map((all) {
      List<Chat> filtered = all.where((c) {
        if (c.presetJson == null) return false;
        try {
          final m = jsonDecode(c.presetJson!) as Map<String, dynamic>;
          final f = (m['folder'] ?? {}) as Map<String, dynamic>;
          return f['spaceId'] == spaceId && f['folderId'] == folderId;
        } catch (_) {
          return false;
        }
      }).toList();

      filtered.sort((a, b) => b.lastAt.compareTo(a.lastAt));
      if (filtered.length > 5) filtered = filtered.sublist(0, 5);
      return filtered;
    });
  }


  Stream<List<Chat>> watchChatsByPersona(String personaId) {
    return watchChats().map((all) {
      final filtered = all.where((chat) {
        if (chat.presetJson == null || chat.presetJson!.trim().isEmpty) return false;
        try {
          final m = jsonDecode(chat.presetJson!) as Map<String, dynamic>;
          return (m['kind'] == 'persona' || m['kind'] == 'bot') && m['id'] == personaId;
        } catch (_) {
          return false;
        }
      }).toList();
      filtered.sort((a, b) => b.lastAt.compareTo(a.lastAt));
      return filtered;
    });
  }

  Future<Chat?> getChat(String id) async {
    return (db.select(db.chats)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> rename(String id, String newName) async {
    await (db.update(db.chats)..where((t) => t.id.equals(id))).write(
      ChatsCompanion(
        name: Value(newName),
        lastAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> toggleStar(String id) async {
    final row =
        await (db.select(db.chats)..where((t) => t.id.equals(id))).getSingle();

    await (db.update(db.chats)..where((t) => t.id.equals(id))).write(
      ChatsCompanion(
        starred: Value(!row.starred),
        lastAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> touch(String id) async {
    await (db.update(db.chats)..where((t) => t.id.equals(id))).write(
      ChatsCompanion(lastAt: Value(DateTime.now().millisecondsSinceEpoch)),
    );
  }

  Future<void> deleteChat(String id) async {
    await (db.delete(db.chatMessages)..where((m) => m.chatId.equals(id))).go();
    await (db.delete(db.chats)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Message>> watchMessages(String chatId) {
    final q = db.select(db.chatMessages)
      ..where((m) => m.chatId.equals(chatId))
      ..orderBy([(m) => OrderingTerm.asc(m.ts)]);
    return q.watch();
  }

  Future<int> addMessage({
    required String chatId,
    required String role,
    required String text,
  }) async {
    final id = await db.into(db.chatMessages).insert(
          ChatMessagesCompanion.insert(
            chatId: chatId,
            role: role,
            text_: text,
            ts: DateTime.now().millisecondsSinceEpoch,
          ),
        );
    await touch(chatId);
    return id;
  }

  Future<void> clearMessages(String chatId) async {
    await (db.delete(db.chatMessages)..where((m) => m.chatId.equals(chatId))).go();
    await touch(chatId);
  }

  Future<List<Chat>> getChatsByModel(String modelId) async {
    final all = await (db.select(db.chats)
          ..orderBy([(t) => OrderingTerm.desc(t.lastAt)]))
        .get();
    final visible = await _filterHistoryVisibleChats(all);
    return visible.where((chat) => _extractModelId(chat) == modelId).toList(growable: false);
  }

  Future<List<Message>> getMessages(String chatId) async {
    final q = db.select(db.chatMessages)
      ..where((m) => m.chatId.equals(chatId))
      ..orderBy([(m) => OrderingTerm.asc(m.ts)]);
    return q.get();
  }


  Future<String> ensureChatByName({
    required String name,
    Map<String, dynamic>? preset,
  }) async {
    final existing = await (db.select(db.chats)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) {
      await touch(existing.id);
      return existing.id;
    }

    return createChat(name: name, preset: preset);
  }

  Future<void> addMediaEntry({
    String chatName = 'Media Inbox',
    required String mediaType,
    required String modelName,
    required String prompt,
    required List<String> urls,
  }) async {
    final chatId = await ensureChatByName(
      name: chatName,
      preset: {
        'kind': 'media_inbox',
        'mediaType': mediaType,
      },
    );

    final buffer = StringBuffer();
    buffer.writeln('[]');
    buffer.writeln('Model: ');
    buffer.writeln('Prompt: ');

    if (urls.isNotEmpty) {
      buffer.writeln('Files:');
      for (final url in urls) {
        buffer.writeln(url);
      }
    }

    await addMessage(
      chatId: chatId,
      role: 'assistant',
      text: buffer.toString().trim(),
    );
  }
  String? _extractModelId(Chat chat) {
    final raw = chat.presetJson;
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final candidates = <String?>[
        decoded['modelId']?.toString(),
        decoded['model']?.toString(),
        decoded['selectedModelId']?.toString(),
        decoded['providerModelId']?.toString(),
      ];

      for (final c in candidates) {
        final v = c?.trim();
        if (v != null && v.isNotEmpty) return v;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
