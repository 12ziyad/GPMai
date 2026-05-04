// lib/screens/space_hub_page.dart
import 'package:flutter/material.dart';

import '../services/sql_chat_store.dart';
import 'chat_page.dart';

class SpaceHubPage extends StatefulWidget {
  final String userId;
  const SpaceHubPage({super.key, required this.userId});

  @override
  State<SpaceHubPage> createState() => _SpaceHubPageState();
}

class _SpaceHubPageState extends State<SpaceHubPage> {
  final _search = TextEditingController();
  final store = SqlChatStore();

  Future<void> _createNewChat() async {
    final id = await store.createChat(name: 'New Chat');
    if (!mounted) return;
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, a1, __) => FadeTransition(
        opacity: a1,
        child: ChatPage(userId: widget.userId, chatId: id, chatName: 'New Chat'),
      ),
    ));
  }

  Future<void> _renameChat(String id, String oldName) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename chat"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Chat title"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await store.rename(id, newName);
  }

  Future<void> _deleteChat(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete chat?"),
        content: const Text("This will delete the chat locally."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    if (ok == true) {
      await store.deleteChat(id);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(title: const Text("Space Hub")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewChat,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text("New Chat"),
      ),
      body: Column(
        children: [
          // Quick actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _QuickAction(
                  icon: Icons.bolt_rounded,
                  label: "Quick Chat",
                  color: cs.primary,
                  onTap: _createNewChat,
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.search_rounded,
                  label: "Search",
                  color: isLight ? Colors.black87 : Colors.white,
                  onTap: () => _showSearchSheet(context),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: "Search chats",
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Chats list (from Drift)
          Expanded(
            child: StreamBuilder<List<Chat>>(
              stream: store.watchChats(),
              builder: (_, snap) {
                var items = snap.data ?? const <Chat>[];

                final q = _search.text.trim().toLowerCase();
                if (q.isNotEmpty) {
                  items = items.where((c) => c.name.toLowerCase().contains(q)).toList();
                }

                if (items.isEmpty) {
                  return const Center(child: Text("Nothing here yet. Tap New Chat."));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = items[i];
                    final id = m.id;
                    final name = m.name;

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 280),
                          pageBuilder: (_, a1, __) => FadeTransition(
                            opacity: a1,
                            child: ChatPage(userId: widget.userId, chatId: id, chatName: name),
                          ),
                        ));
                      },
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
                          await _renameChat(id, name);
                        } else if (action == 'delete') {
                          await _deleteChat(id);
                        }
                      },
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isLight ? Colors.black.withOpacity(.06) : Colors.white.withOpacity(.08),
                            child: const Icon(Icons.chat_bubble_outline_rounded),
                          ),
                          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: const Text("Tap to open", maxLines: 1),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: TextField(
          controller: _search,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search chats",
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }
}

/* ------------ small UI widget -------------- */

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isLight ? color.withOpacity(.10) : color.withOpacity(.14),
            border: Border.all(color: color.withOpacity(.38)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isLight ? Colors.black : Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
