import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

typedef MessageActionCallback = Future<void> Function();

class MessageActionsSheet extends StatelessWidget {
  final String messageText;
  final bool isUser;
  final MessageActionCallback? onDelete;
  final VoidCallback? onInfo;

  const MessageActionsSheet({
    super.key,
    required this.messageText,
    required this.isUser,
    this.onDelete,
    this.onInfo,
  });

  static Future<void> open(
    BuildContext context, {
    required String messageText,
    required bool isUser,
    MessageActionCallback? onDelete,
    VoidCallback? onInfo,
  }) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => MessageActionsSheet(
        messageText: messageText,
        isUser: isUser,
        onDelete: onDelete,
        onInfo: onInfo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget tile({
      required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color? color,
    }) {
      return ListTile(
        leading: Icon(icon, color: color ?? cs.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tile(
            icon: Icons.copy_rounded,
            title: "Copy",
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: messageText));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Copied ✅")),
                );
              }
            },
          ),
          tile(
            icon: Icons.ios_share_rounded,
            title: "Share",
            onTap: () => Share.share(messageText),
          ),
          if (onInfo != null)
            tile(
              icon: Icons.info_outline_rounded,
              title: "Message info",
              onTap: onInfo!,
            ),
          if (onDelete != null)
            tile(
              icon: Icons.delete_outline_rounded,
              title: "Delete",
              color: Colors.redAccent,
              onTap: () async => await onDelete!(),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
