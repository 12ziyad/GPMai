
import 'package:flutter/material.dart';

class ScreenChatPage extends StatefulWidget {
  final String userId;
  final String sessionId;

  const ScreenChatPage({
    super.key,
    required this.userId,
    required this.sessionId,
  });

  @override
  State<ScreenChatPage> createState() => _ScreenChatPageState();
}

class _ScreenChatPageState extends State<ScreenChatPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollArrow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      setState(() => _showScrollArrow = !atBottom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSessionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('screen_session')
        .doc(widget.sessionId)
        .collection('messages')
        .orderBy('timestamp');

    return Scaffold(
      appBar: AppBar(
        title: Text("📖 Screen Session – ${widget.sessionId}"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: screenSessionRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;
              if (messages.isEmpty) {
                return const Center(child: Text("No screen content logged."));
              }

              List<Widget> pairedWidgets = [];
              for (int i = 0; i < messages.length; i++) {
                final data = messages[i].data() as Map<String, dynamic>;
                final role = data['role'] ?? 'user';
                final content = data['content'] ?? data['text'] ?? '';
                final time = data['time'] ?? '--:--';

                if (role == "user") {
                  pairedWidgets.add(Card(
                    color: Colors.grey.shade900,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      title: const Text("🧑 Screen Content", style: TextStyle(color: Colors.white)),
                      subtitle: Text(content, style: const TextStyle(color: Colors.white70)),
                      trailing: Text(time, style: const TextStyle(fontSize: 12, color: Colors.white38)),
                    ),
                  ));

                  // Check if next is gpm
                  if (i + 1 < messages.length) {
                    final next = messages[i + 1].data() as Map<String, dynamic>;
                    if (next['role'] == 'gpm') {
                      final reply = next['text'] ?? '';
                      pairedWidgets.add(Card(
                        color: Colors.blueGrey.shade800,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: const Text("🤖 GPMai Reply", style: TextStyle(color: Colors.white)),
                          subtitle: Text(reply, style: const TextStyle(color: Colors.white70)),
                        ),
                      ));
                      i++; // skip next
                    }
                  }
                } else if (role == "gpm") {
                  pairedWidgets.add(Card(
                    color: Colors.blueGrey.shade800,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: const Text("🤖 GPMai Reply", style: TextStyle(color: Colors.white)),
                      subtitle: Text(content, style: const TextStyle(color: Colors.white70)),
                    ),
                  ));
                }
              }

              return ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                children: pairedWidgets,
              );
            },
          ),
          if (_showScrollArrow)
            Positioned(
              bottom: 12,
              right: 12,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.deepPurple,
                child: const Icon(Icons.arrow_downward),
                onPressed: () {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
