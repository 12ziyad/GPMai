import 'package:flutter/material.dart';

class AiBotsPage extends StatelessWidget {
  const AiBotsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            const SizedBox(height: 8),
            _SectionHeader(
              title: 'Official Models',
              onSeeAll: () {}, // later: open full catalog
            ),
            _BotRow(
              leading: _CircleLogo(icon: Icons.bolt_rounded, color: cs.primary),
              title: 'OpenAI GPT-4',
              subtitle:
                  "OpenAI's advanced model, stronger than GPT-4o Mini in quantitative questions",
              onChat: () => _stub(context, 'GPT-4'),
            ),
            _BotRow(
              leading: _CircleLogo(icon: Icons.auto_awesome_rounded, color: cs.primary),
              title: 'OpenAI GPT-4o Mini',
              subtitle:
                  "OpenAI's advanced model, lighter + fast multimodal mini",
              onChat: () => _stub(context, 'GPT-4o Mini'),
            ),
            _BotRow(
              leading: _CircleLogo(icon: Icons.image_rounded, color: cs.primary),
              title: 'Image Generator',
              subtitle: 'Turn your words into unique visual outputs.',
              onChat: () => _stub(context, 'Image Generator'),
            ),
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'Popular Bots',
              onSeeAll: () {},
            ),
            _BotRow(
              leading: const _IconAvatar(color: Color(0xFFEF5DA8), icon: Icons.favorite_rounded),
              title: 'Relationship Doctor',
              subtitle: 'Your 24/7 wingman and love consultant!',
              onChat: () => _stub(context, 'Relationship Doctor'),
            ),
            _BotRow(
              leading: const _IconAvatar(color: Color(0xFF5E9BFF), icon: Icons.visibility_rounded),
              title: 'Spy',
              subtitle:
                  "I help you look up people and stay updated on what’s happening!",
              onChat: () => _stub(context, 'Spy'),
            ),
            _BotRow(
              leading: const _IconAvatar(color: Color(0xFFB0D7FF), icon: Icons.gavel_rounded),
              title: 'Lawyer',
              subtitle:
                  'Best legal advice available in the world. Come have a little chat with me!',
              onChat: () => _stub(context, 'Lawyer'),
            ),
            _BotRow(
              leading: const _IconAvatar(color: Color(0xFFFFE2B5), icon: Icons.auto_awesome_rounded),
              title: 'Astrolog',
              subtitle:
                  'Have you had a personal astrologer before? Here I am!',
              onChat: () => _stub(context, 'Astrolog'),
            ),
            _BotRow(
              leading: const _IconAvatar(color: Color(0xFFFFB38A), icon: Icons.fitness_center_rounded),
              title: 'Personal Trainer',
              subtitle:
                  'I’m just someone who tells you to train and motivates you!',
              onChat: () => _stub(context, 'Personal Trainer'),
            ),
            _BotRow(
              leading: const _IconAvatar(color: Color(0xFFD6C8FF), icon: Icons.medical_services_rounded),
              title: 'Doctor',
              subtitle: 'Here’s your lovely doctor who takes care of you.',
              onChat: () => _stub(context, 'Doctor'),
            ),
            _BotRow(
              leading: const _IconAvatar(color: Color(0xFFC7F6C7), icon: Icons.edit_note_rounded),
              title: 'Writer',
              subtitle:
                  'A writer of any type. Just give me the description and I got you.',
              onChat: () => _stub(context, 'Writer'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static void _stub(BuildContext context, String who) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting chat with $who (skeleton)…')),
    );
  }
}

class _BotRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onChat;

  const _BotRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: leading,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: isLight ? Colors.black.withOpacity(0.65) : Colors.white70,
            height: 1.2,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: onChat,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: cs.primary,
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('CHAT'),
        ),
        onTap: onChat,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See All')),
        ],
      ),
    );
  }
}

class _CircleLogo extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _CircleLogo({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return CircleAvatar(
      radius: 22,
      backgroundColor: isLight ? const Color(0xFFEFF3FF) : Colors.white10,
      child: Icon(icon, color: color),
    );
  }
}

class _IconAvatar extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _IconAvatar({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: color,
      child: Icon(icon, color: Colors.white),
    );
  }
}
