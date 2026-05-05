import 'package:flutter/material.dart';

import 'debate_room_page.dart';
import 'research_canvas_page.dart';

class AILabPage extends StatelessWidget {
  final String userId;
  const AILabPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final subColor = isLight ? Colors.black54 : Colors.white70;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          const Text(
            'AI Lab',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'A premium space for advanced reasoning, multi-step workflows, and flagship experiences built to feel different from normal chat.',
            style: TextStyle(fontSize: 14, height: 1.355, color: subColor),
          ),
          const SizedBox(height: 24),
          _LabCard(
            title: 'Debate Room',
            subtitle:
                'Choose any 3 models. Watch opening views, cross-challenges, refined positions, and a final synthesis.',
            accent: const Color(0xFF12C6FF),
            accent2: const Color(0xFF8D63FF),
            icon: Icons.forum_rounded,
            chip: 'Live now',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DebateRoomPage(userId: userId),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _LabCard(
            title: 'Research Canvas',
            subtitle:
                'A premium workspace for saved answers, manual notes, Debate Room outcomes, and AI-built sections that keep growing over time.',
            accent: const Color(0xFFFF5B93),
            accent2: const Color(0xFF3F7DFF),
            icon: Icons.auto_awesome_mosaic_rounded,
            chip: 'Workspace',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResearchCanvasPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LabCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Color accent2;
  final IconData icon;
  final String chip;
  final VoidCallback? onTap;

  const _LabCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.accent2,
    required this.icon,
    required this.chip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final border = isLight ? Colors.black12 : Colors.white12;
    final subtitleColor = isLight ? Colors.black54 : Colors.white70;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isLight
                    ? [
                      Color.alphaBlend(
                        accent.withOpacity(.24),
                        const Color(0xFFF8FBFF),
                      ),
                      Color.alphaBlend(
                        accent2.withOpacity(.18),
                        const Color(0xFFF3F5FA),
                      ),
                      const Color(0xFFF4F7FB),
                    ]
                    : [
                      Color.alphaBlend(
                        accent.withOpacity(.36),
                        const Color(0xFF121826),
                      ),
                      Color.alphaBlend(
                        accent2.withOpacity(.32),
                        const Color(0xFF141222),
                      ),
                      const Color(0xFF090B11),
                    ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: accent.withOpacity(.16),
                  border: Border.all(color: accent.withOpacity(.45)),
                ),
                child: Icon(icon, color: accent, size: 34),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: accent.withOpacity(.16),
                          ),
                          child: Text(
                            chip,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: subtitleColor,
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Open now',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
