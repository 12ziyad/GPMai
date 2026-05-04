import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownBubble extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color? linkColor;

  const MarkdownBubble({
    super.key,
    required this.text,
    required this.textColor,
    this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final border = isLight ? Colors.black26 : Colors.white24;

    final style = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(color: textColor, fontSize: 15, height: 1.25),
      code: TextStyle(
        color: textColor.withOpacity(.95),
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.25,
      ),
      codeblockDecoration: BoxDecoration(
        color: isLight ? Colors.black.withOpacity(.06) : const Color(0xFF101318),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      tableBorder: TableBorder.all(color: border),
      tableHead: TextStyle(
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      blockquoteDecoration: BoxDecoration(
        color: isLight ? Colors.black.withOpacity(.04) : const Color(0xFF141820),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: border, width: 3)),
      ),
      a: TextStyle(
        color: linkColor ?? const Color(0xFF00B8FF),
        decoration: TextDecoration.underline,
      ),
    );

    return MarkdownBody(
      selectable: true,
      softLineBreak: true,
      data: text,
      styleSheet: style,
      onTapLink: (_, __, ___) {}, // no-op (no url_launcher required)
      imageBuilder: (uri, title, alt) {
        // Keep images tiny-safe inside bubble
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(uri.toString(), fit: BoxFit.cover),
        );
      },
    );
  }
}
