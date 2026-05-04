import 'package:flutter/material.dart';
import 'chat_page.dart'; // we'll create this next

class ChatListPage extends StatefulWidget {
  final String userId;

  const ChatListPage({super.key, required this.userId});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatFirestoreService _chatService = ChatFirestoreService();

  Future<void> _createNewChat() async {
    final chatName = await _showChatNameDialog();
    if (chatName != null && chatName.trim().isNotEmpty) {
      final chatId = await _chatService.createNewChat(
        widget.userId,
        chatName.trim(),
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChatPage(
                  userId: widget.userId,
                  chatId: chatId,
                  chatName: chatName,
                ),
          ),
        );
      }
    }
  }

  Future<String?> _showChatNameDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('New Chat'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter chat name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPMai Chats'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createNewChat),
        ],
      ),
      body: StreamBuilder(
        stream: _chatService.getUserChats(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data?.docs ?? [];

          if (chats.isEmpty) {
            return const Center(
              child: Text('No chats yet. Tap ➕ to create one.'),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (_, index) {
              final chat = chats[index];
              final chatName = chat['chat_name'];
              final chatId = chat.id;

              return ListTile(
                title: Text(chatName),
                subtitle: const Text("Tap to open"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ChatPage(
                            userId: widget.userId,
                            chatId: chatId,
                            chatName: chatName,
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
