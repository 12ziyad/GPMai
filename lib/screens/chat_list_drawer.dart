import 'package:flutter/material.dart';
import '../services/chat_firestore_service.dart';
import '../screens/chat_page.dart';
import '../screens/orb_chat_page.dart';
import '../screens/voice_chat_page.dart';
import '../screens/screen_chat_page.dart'; // ✅ NEW

class ChatListDrawer extends StatelessWidget {
  final String userId;
  final Function(String chatId, String chatName, bool isOrb) onChatSelected;

  const ChatListDrawer({
    super.key,
    required this.userId,
    required this.onChatSelected,
  });

  Future<void> _createNewChat(BuildContext context) async {
    final controller = TextEditingController();
    final chatName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter chat name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );

    if (chatName != null && chatName.trim().isNotEmpty) {
      final chatService = ChatFirestoreService();
      final chatId = await chatService.createNewChat(userId, chatName.trim());
      onChatSelected(chatId, chatName.trim(), false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = ChatFirestoreService();

    return Drawer(
      child: Row(
        children: [
          Container(width: MediaQuery.of(context).size.width * 0.35, color: Colors.blue.shade700),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _createNewChat(context),
                    icon: const Icon(Icons.add),
                    label: const Text('New Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  const Divider(),

                  // 🧠 Regular Chats
                  Expanded(
                    child: StreamBuilder(
                      stream: chatService.getUserChats(userId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final chats = snapshot.data!.docs;

                        return ListView(
                          padding: const EdgeInsets.only(top: 12),
                          children: [
                            if (chats.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('Chats', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...chats.map((chat) {
                                final chatId = chat.id;
                                final chatName = chat['chat_name'] ?? 'Unnamed';
                                return ListTile(
                                  title: Text(chatName, style: const TextStyle(color: Colors.black)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Delete Chat"),
                                          content: Text("Delete '$chatName'?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) await chatService.deleteChat(userId, chatId);
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    onChatSelected(chatId, chatName, false);
                                  },
                                );
                              }).toList(),
                            ],

                            const Divider(),

                            // 🧠 Orb Sessions
                            StreamBuilder(
                              stream: chatService.getOrbSessions(userId),
                              builder: (context, orbSnap) {
                                if (!orbSnap.hasData) return const SizedBox();
                                final orbChats = orbSnap.data!.docs;
                                if (orbChats.isEmpty) return const SizedBox();
                                return ExpansionTile(
                                  title: const Text("Orb Sessions"),
                                  children: orbChats.map((orbChat) {
                                    final chatId = orbChat.id;
                                    return ListTile(
                                      title: Text(chatId, style: const TextStyle(color: Colors.black)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => OrbChatPage(userId: userId, sessionId: chatId),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                            ),

                            // 🔊 Voice Sessions
                            StreamBuilder(
                              stream: chatService.getVoiceSessions(userId),
                              builder: (context, voiceSnap) {
                                if (!voiceSnap.hasData) return const SizedBox();
                                final voiceSessions = voiceSnap.data!.docs;
                                if (voiceSessions.isEmpty) return const SizedBox();
                                return ExpansionTile(
                                  title: const Text("Voice Sessions"),
                                  children: voiceSessions.map((voiceChat) {
                                    final sessionId = voiceChat.id;
                                    return ListTile(
                                      title: Text(sessionId, style: const TextStyle(color: Colors.black)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => VoiceChatPage(userId: userId, sessionId: sessionId),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                            ),

                            // 📖 Screen Reading Sessions (✅ Updated)
                            StreamBuilder(
                              stream: chatService.getScreenSessions(userId),
                              builder: (context, screenSnap) {
                                if (!screenSnap.hasData) return const SizedBox();
                                final screenSessions = screenSnap.data!.docs;
                                if (screenSessions.isEmpty) return const SizedBox();
                                return ExpansionTile(
                                  title: const Text("Screen Reading Sessions"),
                                  children: screenSessions.map((screenChat) {
                                    final sessionId = screenChat.id;
                                    return ListTile(
                                      title: Text(sessionId, style: const TextStyle(color: Colors.black)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ScreenChatPage(
                                              userId: userId,
                                              sessionId: sessionId,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
