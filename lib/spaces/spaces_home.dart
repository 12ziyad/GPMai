import 'package:flutter/material.dart';
import 'spaces_config.dart';

class SpacesHome extends StatelessWidget {
  final void Function(SpaceConfig space) onOpenSpace;
  const SpacesHome({super.key, required this.onOpenSpace});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 1.1),
      itemCount: spaces.length,
      itemBuilder: (_, i) {
        final s = spaces[i];
        return _SpaceCard(space: s, onTap: () => onOpenSpace(s));
      },
    );
  }
}

class _SpaceCard extends StatelessWidget {
  final SpaceConfig space;
  final VoidCallback onTap;
  const _SpaceCard({required this.space, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(space.icon, size: 28, color: space.color),
              const Spacer(),
              Text(space.name, style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: space.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text("Open", style: TextStyle(fontSize: 12)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
