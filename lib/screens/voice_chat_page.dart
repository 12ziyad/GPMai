import 'package:flutter/material.dart';

class VoiceChatComingSoonPage extends StatelessWidget {
  const VoiceChatComingSoonPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hands-free Voice')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_none_rounded, size: 72, color: cs.primary),
              const SizedBox(height: 16),
              const Text(
                'Hands-free Voice\nComing in the next update',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'We’re polishing the realtime voice chat.\nStay tuned! 🎧',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
