import 'package:flutter/material.dart';
import '../groq/model_router.dart';

class TestGroqPage extends StatefulWidget {
  const TestGroqPage({super.key});

  @override
  State<TestGroqPage> createState() => _TestGroqPageState();
}

class _TestGroqPageState extends State<TestGroqPage> {
  final TextEditingController _controller = TextEditingController();
  String _reply = '';
  bool _loading = false;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _reply = '';
    });

    print("📡 Sending to Groq: $text");

    try {
      final response = await ModelRouter.getResponse(text);
      print("✅ Groq replied: $response");

      setState(() {
        _reply = response;
      });
    } catch (e) {
      print("❌ Error: $e");
      setState(() {
        _reply = "[Error] $e";
      });
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("GPMai Groq Test")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                labelText: "Enter your message",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _sendMessage,
              child:
                  _loading
                      ? const CircularProgressIndicator()
                      : const Text("Send to GPMai"),
            ),
            const SizedBox(height: 24),
            if (_reply.isNotEmpty)
              Card(
                color: Colors.green[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_reply, style: const TextStyle(fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
