import 'package:flutter/material.dart';

class MemoryModeChip extends StatelessWidget {
  final VoidCallback? onOpenHub;
  final ValueChanged<String>? onModeChanged;
  final bool compact;

  const MemoryModeChip({
    super.key,
    this.onOpenHub,
    this.onModeChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onOpenHub,
      borderRadius: BorderRadius.circular(compact ? 16 : 18),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: isLight ? Colors.white.withOpacity(.88) : const Color(0xFF111826),
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
          border: Border.all(color: color.withOpacity(.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hub_rounded, size: compact ? 16 : 18, color: color),
            const SizedBox(width: 8),
            Text(
              'Unified memory',
              style: TextStyle(
                fontSize: compact ? 12.5 : 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
