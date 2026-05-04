import 'package:flutter/material.dart';
import 'spaces_config.dart';

class SpaceDetail extends StatelessWidget {
  final SpaceConfig space;
  final void Function(SpaceConfig, String? seedMessage) onStartChat;
  const SpaceDetail({super.key, required this.space, required this.onStartChat});

  @override
  Widget build(BuildContext context) {
    final hasChildren = space.children.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(space: space),
        if (hasChildren) ...[
          const SizedBox(height: 12),
          Text("Categories", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: space.children.map((c) => ActionChip(
              avatar: Icon(c.icon, size: 18, color: c.color),
              label: Text(c.name),
              onPressed: () => onStartChat(c, null),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (space.starterPrompts.isNotEmpty) ...[
          Text("Examples", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...space.starterPrompts.map((p) => _PromptTile(
            text: p, onTap: () => onStartChat(space, p),
          )),
        ]
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final SpaceConfig space;
  const _Header({required this.space});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      CircleAvatar(
        radius: 24,
        backgroundColor: space.color.withOpacity(.15),
        child: Icon(space.icon, color: space.color),
      ),
      const SizedBox(width: 12),
      Text(space.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _PromptTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _PromptTile({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(text),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
