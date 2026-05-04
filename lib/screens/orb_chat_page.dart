import 'package:flutter/material.dart';


class OrbChatPage extends StatelessWidget {
  final String userId;
  final String sessionId;

  const OrbChatPage({
    super.key,
    required this.userId,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final messagesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('orb_session')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp');

    return Scaffold(
      appBar: AppBar(title: Text('Orb Session - $sessionId')),
      body: StreamBuilder(
        stream: messagesRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isUser = msg['role'] == 'user';
              final text = msg['text'] ?? '';
              final alignment = isUser
                  ? Alignment.centerRight
                  : Alignment.centerLeft;
              final bubbleColor = isUser ? Colors.white : Colors.blue;
              final textColor = isUser ? Colors.blue : Colors.white;

              return Container(
                alignment: alignment,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: screenWidth * 0.75,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(color: textColor, fontSize: 15),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
