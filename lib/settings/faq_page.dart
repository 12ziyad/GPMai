// lib/settings/faq_page.dart
import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  Widget _q(BuildContext context, String q, String a) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isLight ? Colors.black.withOpacity(.035) : Colors.white.withOpacity(.05),
        border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
      ),
      child: ListTile(
        title: Text(q, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(a),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final faqs = <(String, String)>[
      (
        'Does the app watch my screen all the time?',
        'No. GPMai only processes what you explicitly share — text you type, voice you choose to record, files you pick, or a one-time snapshot when you tap a feature like “Ask about this screen.”'
      ),
      (
        'Where is my chat history stored?',
        'On your device. Local storage lets you revisit previous chats. You can delete them from the Inbox at any time.'
      ),
      (
        'What happens to the images or one-time snapshots I share?',
        'They are used to generate the answer and then discarded. They are not added to long-term storage.'
      ),
      (
        'Do you sell my data or run ads?',
        'No. We do not sell your data or build advertising profiles.'
      ),
      (
        'What should I do if something looks wrong?',
        'AI can be imperfect. Ask again with more detail, or contact us via the “Report / Feedback” option in Settings.'
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const SizedBox(height: 6),
            ...faqs.map((e) => _q(context, e.$1, e.$2)),
          ],
        ),
      ),
    );
  }
}
