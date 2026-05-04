import 'package:flutter/material.dart';
import '../services/gpmai_api_client.dart';

class TestCloudflarePage extends StatefulWidget {
  const TestCloudflarePage({super.key});

  @override
  State<TestCloudflarePage> createState() => _TestCloudflarePageState();
}

class _TestCloudflarePageState extends State<TestCloudflarePage> {
  bool? healthOk;
  bool loading = false;
  String result = "";

  Future<void> runHealth() async {
    setState(() {
      loading = true;
      result = "";
    });
    try {
      final ok = await GpmaiApiClient.health();
      setState(() => healthOk = ok);
    } catch (e) {
      setState(() => result = "Health error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> runChat() async {
    setState(() {
      loading = true;
      result = "";
    });

    try {
      final data = await GpmaiApiClient.chat(
        model: "openai/gpt-4o-mini",
        messages: [
          {"role": "user", "content": "hello from flutter test"},
        ],
      );

      final text = GpmaiApiClient.extractText(data);
      setState(() => result = text.isEmpty ? data.toString() : text);
    } catch (e) {
      setState(() => result = "Chat error: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Test Cloudflare")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: loading ? null : runHealth,
              child: const Text("Test /health"),
            ),
            const SizedBox(height: 10),
            if (healthOk != null)
              Text(
                healthOk == true ? "✅ Health OK" : "❌ Health FAILED",
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : runChat,
              child: const Text("Test /chat"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(result.isEmpty ? "No result yet..." : result),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
