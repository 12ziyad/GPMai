// lib/spaces/space_folders_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/sql_chat_store.dart';
import '../screens/chat_page.dart';
import 'spaces_config.dart';
import '../prompts/prompt_builders.dart'; // NEW

// Electric blue used elsewhere
const _electricBlue = Color(0xFF00B8FF);

Color _mix(Color a, Color b, double t) => Color.fromARGB(
  (a.alpha + (b.alpha - a.alpha) * t).round(),
  (a.red + (b.red - a.red) * t).round(),
  (a.green + (b.green - a.green) * t).round(),
  (a.blue + (b.blue - a.blue) * t).round(),
);

Color _adaptiveBorder(BuildContext ctx) {
  final cs = Theme.of(ctx).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  return (isDark ? _electricBlue : Colors.black87).withOpacity(isDark ? .35 : .18);
}

Color _pillBg(BuildContext ctx, {bool selected = false}) {
  final cs = Theme.of(ctx).colorScheme;
  return selected
      ? (cs.brightness == Brightness.dark ? _electricBlue : cs.primary)
      : cs.surfaceVariant.withOpacity(.24);
}

class SpaceFoldersPage extends StatefulWidget {
  final String spaceId;
  final String spaceTitle;

  /// If true, don't auto-seed starter folders (user-created custom space).
  final bool isCustom;

  /// List of spaces (from Explore) so we can keep the chips visible everywhere.
  final List<dynamic>? allSpaces;

  /// Which chip should be focused initially.
  final String? initialChipId;

  const SpaceFoldersPage({
    super.key,
    required this.spaceId,
    required this.spaceTitle,
    this.isCustom = false,
    this.allSpaces,
    this.initialChipId,
  });

  @override
  State<SpaceFoldersPage> createState() => _SpaceFoldersPageState();
}

class _SpaceFoldersPageState extends State<SpaceFoldersPage> {
  final SqlChatStore store = SqlChatStore();

  /// simple in-memory folders list per space (title + about + id)
  late List<_Folder> folders =
      widget.isCustom ? <_Folder>[] : _seedForSpace(widget.spaceId, widget.spaceTitle);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final body = folders.isEmpty && widget.isCustom
        ? _EmptyTip(onCreate: _createFolderDialog)
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: folders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _FolderCard(
              spaceId: widget.spaceId,
              spaceTitle: widget.spaceTitle,
              folder: folders[i],
              onOpen: () => _openFolder(folders[i]),
              onRename: (title, about) {
                setState(() {
                  folders[i] = folders[i].copyWith(title: title, about: about);
                });
              },
              onDelete: () {
                setState(() {
                  folders.removeAt(i);
                });
              },
              onStarToggle: () {
                setState(() {
                  folders[i] = folders[i].copyWith(starred: !folders[i].starred);
                });
              },
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.spaceTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _ChipsBar(
            items: _makeChipItems(widget.allSpaces),
            currentId: widget.spaceId,
            initialId: widget.initialChipId ?? widget.spaceId,
            onTap: (it) => _goToSpace(context, it),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: cs.primary,
        foregroundColor: Colors.black,
        onPressed: _createFolderDialog,
        child: const Icon(Icons.create_new_folder_rounded),
      ),
      body: body,
    );
  }

  Future<void> _createFolderDialog() async {
    final title = TextEditingController();
    final about = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("New Folder"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(hintText: "Title")),
            const SizedBox(height: 8),
            TextField(controller: about, decoration: const InputDecoration(hintText: "About (purpose)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Create")),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      setState(() {
        folders.add(_Folder(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title.text.trim(),
          about: about.text.trim(),
        ));
      });
    }
  }

  void _openFolder(_Folder f) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, a, __) => FadeTransition(
        opacity: a,
        child: FolderDetailPage(
          spaceId: widget.spaceId,
          spaceTitle: widget.spaceTitle,
          folder: f,
          allSpaces: widget.allSpaces,
          initialChipId: widget.spaceId,
        ),
      ),
    ));
  }

  /* ─ chips data ─ */

  List<_ChipItem> _makeChipItems(List<dynamic>? items) {
    if (items == null) return const [];
    return items.map<_ChipItem>((e) {
      final d = e as dynamic;
      final String id = d.id as String;
      final String title = d.title as String;
      final bool isCustom = (d.isCustom as bool?) ?? false;
      return _ChipItem(id: id, title: title, isCustom: isCustom);
    }).toList();
  }

  void _goToSpace(BuildContext context, _ChipItem it) {
    if (it.id == widget.spaceId) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, a, __) => FadeTransition(
        opacity: a,
        child: SpaceFoldersPage(
          spaceId: it.id,
          spaceTitle: it.title,
          isCustom: it.isCustom,
          allSpaces: widget.allSpaces,
          initialChipId: it.id,
        ),
      ),
    ));
  }
}

/* ───────── folder detail page ───────── */

class FolderDetailPage extends StatelessWidget {
  final String spaceId;
  final String spaceTitle;
  final _Folder folder;

  final List<dynamic>? allSpaces;
  final String? initialChipId;

  FolderDetailPage({
    super.key,
    required this.spaceId,
    required this.spaceTitle,
    required this.folder,
    this.allSpaces,
    this.initialChipId,
  });

  final SqlChatStore store = SqlChatStore();
  final TextEditingController _ask = TextEditingController();

  String _systemPrompt() {
    // Use the shared builder (keeps behavior consistent across all spaces incl. custom)
    return buildFolderSystemPrompt(
      spaceName: spaceTitle,
      folderName: folder.title,
      about: folder.about.isEmpty ? "general discussion" : folder.about,
    );
  }

  String _welcomeText() {
    return buildFolderWelcome(
      spaceName: spaceTitle,
      folderName: folder.title,
      about: folder.about,
    );
  }

  Future<void> _goToChat(BuildContext context, String seed) async {
    final prompt = _systemPrompt();
    final welcome = _welcomeText();

    // Keep preset for recents filtering; the model uses systemPrompt passed to ChatPage.
    final preset = {
      'kind': 'folder_chat',
      'folder': {
        'spaceId': spaceId,
        'spaceTitle': spaceTitle,
        'folderId': folder.id,
        'folderTitle': folder.title,
        'about': folder.about,
        'systemPrompt': prompt,
      }
    };

    final id = await store.createChat(name: folder.title, preset: preset);

    if (!context.mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, a, __) => FadeTransition(
        opacity: a,
        child: ChatPage(
          userId: "local",
          chatId: id,
          chatName: folder.title,
          systemPrompt: prompt,        // NEW: model sees per-folder prompt
          welcome: welcome,            // NEW: one-time 💡 welcome
          seedUserText: seed.trim(),   // NEW: optional seed goes immediately
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(folder.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _ChipsBar(
            items: _makeChipItems(allSpaces),
            currentId: spaceId,
            initialId: initialChipId ?? spaceId,
            onTap: (it) => _goToSpace(context, it),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // top half — input card
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folder.about.isEmpty ? "Ask about ${folder.title}…" : folder.about,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ask,
                      decoration: const InputDecoration(
                        hintText: "Type to start a chat in this folder",
                        border: InputBorder.none,
                      ),
                      onSubmitted: (v) => _goToChat(context, v),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _goToChat(context, _ask.text),
                    style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.black),
                    child: const Text("Go"),
                  )
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Recents", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          // ─────────────── RECENTS (with long-press actions) ───────────────
          StreamBuilder<List<Chat>>(
            stream: store.watchLast5ForFolder(spaceId: spaceId, folderId: folder.id),
            builder: (_, snap) {
              final items = snap.data ?? const <Chat>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("No chats yet. Start one above."),
                );
              }
              final isLight = Theme.of(context).brightness == Brightness.light;

              Future<void> _renameChat(Chat c) async {
                final cCtrl = TextEditingController(text: c.name);
                final newName = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Rename chat"),
                    content: TextField(
                      controller: cCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: "Chat title"),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      ElevatedButton(onPressed: () => Navigator.pop(context, cCtrl.text.trim()), child: const Text("Save")),
                    ],
                  ),
                );
                if (newName == null || newName.isEmpty) return;
                await store.rename(c.id, newName);
              }

              Future<void> _deleteChat(Chat c) async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Delete chat?"),
                    content: const Text("This will remove the chat locally."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                    ],
                  ),
                );
                if (ok == true) {
                  await store.deleteChat(c.id);
                }
              }

              Future<void> _toggleStar(Chat c) async {
                await store.toggleStar(c.id);
              }

              return Column(
                children: items.map((c) {
                  return GestureDetector(
                    onLongPress: () async {
                      final action = await showModalBottomSheet<String>(
                        context: context,
                        showDragHandle: true,
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                                title: const Text("Rename"),
                                onTap: () => Navigator.pop(context, 'rename'),
                              ),
                              ListTile(
                                leading: Icon(
                                  c.starred ? Icons.star_outline_rounded : Icons.star_rounded,
                                  color: _electricBlue,
                                ),
                                title: Text(c.starred ? "Unstar" : "Star"),
                                onTap: () => Navigator.pop(context, 'star'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                title: const Text("Delete"),
                                onTap: () => Navigator.pop(context, 'delete'),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      );

                      if (action == 'rename') {
                        await _renameChat(c);
                      } else if (action == 'delete') {
                        await _deleteChat(c);
                      } else if (action == 'star') {
                        await _toggleStar(c);
                      }
                    },
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          c.starred ? Icons.star_rounded : Icons.chat_bubble_outline_rounded,
                          color: c.starred
                              ? _electricBlue
                              : (isLight ? Colors.black87 : null),
                        ),
                        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          DateTime.fromMillisecondsSinceEpoch(c.lastAt).toLocal().toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 240),
                            pageBuilder: (_, a, __) => FadeTransition(
                              opacity: a,
                              child: ChatPage(
                                userId: "local",
                                chatId: c.id,
                                chatName: c.name,
                                // Re-hydrate the per-folder prompt + welcome if available in presetJson.
                                systemPrompt: _rehydrateSystemPrompt(c.presetJson),
                                welcome: _rehydrateWelcome(c.presetJson),
                              ),
                            ),
                          ));
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /* chips helpers (local copy, no import of Explore) */

  List<_ChipItem> _makeChipItems(List<dynamic>? items) {
    if (items == null) return const [];
    return items.map<_ChipItem>((e) {
      final d = e as dynamic;
      final String id = d.id as String;
      final String title = d.title as String;
      final bool isCustom = (d.isCustom as bool?) ?? false;
      return _ChipItem(id: id, title: title, isCustom: isCustom);
    }).toList();
  }

  void _goToSpace(BuildContext context, _ChipItem it) {
    if (it.id == spaceId) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, a, __) => FadeTransition(
        opacity: a,
        child: SpaceFoldersPage(
          spaceId: it.id,
          spaceTitle: it.title,
          isCustom: it.isCustom,
          allSpaces: allSpaces,
          initialChipId: it.id,
        ),
      ),
    ));
  }

  // Rehydrate helpers for opening from Recents
  String? _rehydrateSystemPrompt(String? presetJson) {
    if (presetJson == null) return null;
    try {
      final m = jsonDecode(presetJson) as Map<String, dynamic>;
      final folder = (m['folder'] ?? {}) as Map<String, dynamic>;
      final sp = (folder['systemPrompt'] ?? '') as String;
      if (sp.trim().isNotEmpty) return sp;
      // fallback: rebuild
     return buildFolderSystemPrompt(
  spaceName: (folder['spaceTitle'] as String?) ?? spaceTitle,
  folderName: (folder['folderTitle'] as String?) ?? (folder['title'] as String?) ?? 'Chat',
  about: (folder['about'] as String?) ?? '',
);
    } catch (_) {
      return null;
    }
  }

  String? _rehydrateWelcome(String? presetJson) {
    if (presetJson == null) return null;
    try {
     final m = jsonDecode(presetJson) as Map<String, dynamic>;
final folder = (m['folder'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

final space = (folder['spaceTitle'] as String?) ?? spaceTitle;
final title = (folder['folderTitle'] as String?) ?? (folder['title'] as String?) ?? 'Chat';
final about = (folder['about'] as String?) ?? '';

return buildFolderWelcome(spaceName: space, folderName: title, about: about);
    } catch (_) {
      return null;
    }
  }
}

/* ───────── models/helpers ───────── */

class _Folder {
  final String id;
  final String title;
  final String about;
  final bool starred;
  const _Folder({required this.id, required this.title, this.about = "", this.starred = false});
  _Folder copyWith({String? title, String? about, bool? starred}) =>
      _Folder(id: id, title: title ?? this.title, about: about ?? this.about, starred: starred ?? this.starred);
}

/// seed 3 folders per built-in spaces (custom spaces start empty)
List<_Folder> _seedForSpace(String spaceId, String spaceTitle) {
  List<_Folder> three(String a, String b, String c) => [
        _Folder(id: "1_$spaceId", title: a, about: "$spaceTitle - $a"),
        _Folder(id: "2_$spaceId", title: b, about: "$spaceTitle - $b"),
        _Folder(id: "3_$spaceId", title: c, about: "$spaceTitle - $c"),
      ];
  switch (spaceId) {
    case 'fun':
      return three("Birthday Party", "Weekend Games", "Memes & Jokes");
    case 'health':
      return three("Diet Plan", "Workout Logs", "Mental Wellness");
    case 'greetings':
      return three("Wishes", "Thank You Notes", "Invitations");
    case 'email':
      return three("Client Outreach", "Follow-ups", "Internal Updates");
    case 'communication':
      return three("Team Updates", "Customer Replies", "Crisis Comms");
    case 'education':
      return three("Study Notes", "Quiz Maker", "Explainers");
    case 'work':
      return three("Daily Standup", "Specs Drafts", "Retros");
    case 'marketing':
      return three("Ad Ideas", "Launch Plan", "Content Calendar");
    case 'social':
      return three("Twitter/X Posts", "Instagram Captions", "LinkedIn Updates");
    case 'ideas':
      return three("Brainstorm", "MVP Scope", "Naming");
    case 'cooking':
      return three("Meal Prep", "Recipes", "Groceries");
    case 'lifestyle':
      return three("Routines", "Habits", "Budgeting");
    default:
      return three("Folder A", "Folder B", "Folder C");
  }
}

/* ───────── folder tile ───────── */

class _FolderCard extends StatelessWidget {
  final String spaceId;
  final String spaceTitle;
  final _Folder folder;
  final VoidCallback onOpen;
  final void Function(String title, String about) onRename;
  final VoidCallback onDelete;
  final VoidCallback onStarToggle;
  const _FolderCard({
    required this.spaceId,
    required this.spaceTitle,
    required this.folder,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onStarToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onLongPress: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text("Rename"),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
              ListTile(
                leading: Icon(folder.starred ? Icons.star_outline : Icons.star, color: cs.primary),
                title: Text(folder.starred ? "Unstar" : "Star"),
                onTap: () => Navigator.pop(context, 'star'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                title: const Text("Delete"),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
        if (action == 'rename') {
          final t = TextEditingController(text: folder.title);
          final a = TextEditingController(text: folder.about);
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Edit Folder"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: t, decoration: const InputDecoration(hintText: "Title")),
                const SizedBox(height: 8),
                TextField(controller: a, decoration: const InputDecoration(hintText: "About")),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
              ],
            ),
          );
          if (ok == true && t.text.trim().isNotEmpty) onRename(t.text.trim(), a.text.trim());
        } else if (action == 'delete') {
          onDelete();
        } else if (action == 'star') {
          onStarToggle();
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: cs.primary.withOpacity(.15),
              child: Icon(
                folder.starred ? Icons.star : Icons.folder_rounded,
                color: folder.starred ? cs.primary : (isLight ? Colors.black87 : Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folder.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  folder.about.isEmpty ? "No description" : folder.about,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onOpen,
              style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.black),
              child: const Text("Open"),
            )
          ]),
        ),
      ),
    );
  }
}

/* ───────── shared chips (local widget) ───────── */

class _ChipItem {
  final String id;
  final String title;
  final bool isCustom;
  const _ChipItem({required this.id, required this.title, this.isCustom = false});
}

class _ChipsBar extends StatefulWidget {
  final List<_ChipItem> items;
  final String currentId;
  final String initialId;
  final void Function(_ChipItem it) onTap;
  const _ChipsBar({
    required this.items,
    required this.currentId,
    required this.initialId,
    required this.onTap,
  });

  @override
  State<_ChipsBar> createState() => _ChipsBarState();
}

class _ChipsBarState extends State<_ChipsBar> {
  final _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // after first layout, scroll the current chip near center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = widget.items.indexWhere((e) => e.id == widget.initialId);
      if (idx <= 0) return;
      final target = (idx * 100).toDouble(); // rough; ok for pills
      _ctrl.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        controller: _ctrl,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        scrollDirection: Axis.horizontal,
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final it = widget.items[i];
          final selected = it.id == widget.currentId;
          return _pill(context, it.title, selected: selected, onTap: () => widget.onTap(it));
        },
      ),
    );
  }

  Widget _pill(BuildContext ctx, String text, {bool selected = false, VoidCallback? onTap}) {
    final cs = Theme.of(ctx).colorScheme;
    final bg = _pillBg(ctx, selected: selected);
    final fg = selected ? (cs.brightness == Brightness.dark ? Colors.black : Colors.white)
                        : (cs.brightness == Brightness.dark ? cs.onSurface : Colors.black87);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _adaptiveBorder(ctx)),
        ),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/* ───────── empty tip ───────── */

class _EmptyTip extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyTip({required this.onCreate});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.create_new_folder_rounded, size: 44, color: cs.primary),
            const SizedBox(height: 12),
            const Text("No folders yet",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              "Tip: tap the blue + button to create your first folder in this space.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Create folder"),
              style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
