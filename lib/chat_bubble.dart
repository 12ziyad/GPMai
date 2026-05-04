import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatBubble extends StatefulWidget {
  final VoidCallback onClose;

  const ChatBubble({super.key, required this.onClose});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  final TextEditingController _controller = TextEditingController();
  String _response = "";
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = "";
    });

    try {
      final res = await http.post(
        Uri.parse(
          "http://localhost:8000/chat",
        ), // 👈 Change this if hosted elsewhere
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"message": input}),
      );

      final data = jsonDecode(res.body);
      setState(() {
        _response = data['response'] ?? "No response.";
      });
    } catch (e) {
      setState(() {
        _response = "❌ Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: "Say something...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Response
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_response.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_response, style: const TextStyle(fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }
}
