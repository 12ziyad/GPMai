import 'package:flutter/material.dart';
import '../spaces/space_folders_page.dart';

/// Electric blue accent used across themes.
const _electricBlue = Color(0xFF00B8FF);

/// Neutral accent for custom spaces (black/graphite)
const _customAccentStart = Color(0xFF2B2F36);
const _customAccentEnd = Color(0xFF3A3F46);

class ExplorePage extends StatefulWidget {
  final void Function(String id)? onTapCategory;
  final void Function(String id)? onTapTool;
  final VoidCallback? onCreateFolder;

  const ExplorePage({super.key, this.onTapCategory, this.onTapTool, this.onCreateFolder});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  /// Start with built-ins (Productivity removed). We’ll append user-created spaces.
  final List<CategoryItem> _items = List<CategoryItem>.from(_builtin);

  void _sortItems() {
    // custom first, then pinned, then alphabetical
    _items.sort((a, b) {
      final c1 = (b.isCustom ? 1 : 0) - (a.isCustom ? 1 : 0);
      if (c1 != 0) return c1;
      final c2 = (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0);
      if (c2 != 0) return c2;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  void _openSpace(CategoryItem it) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, a, __) => FadeTransition(
        opacity: a,
        child: SpaceFoldersPage(
          spaceId: it.id,
          spaceTitle: it.title,
          isCustom: it.isCustom,     // don’t seed folders for custom
          allSpaces: _items,         // chips everywhere until chat
          initialChipId: it.id,      // keep chip position focused
        ),
      ),
    ));
  }

  void _createSpaceFlow() async {
    final created = await showModalBottomSheet<_NewSpaceResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _CreateSpaceSheet(),
    );
    if (created == null) return;

    final id = 'user_${DateTime.now().microsecondsSinceEpoch}';
    final letter = created.icon == null && created.name.isNotEmpty
        ? created.name.trim()[0].toUpperCase()
        : null;

    final cat = CategoryItem(
      id,
      created.name,
      created.icon, // can be null
      const [_customAccentStart, _customAccentEnd],
      Theme.of(context).colorScheme.onSurface,
      isCustom: true,
      pinned: false,          // do not auto-pin
      letter: letter,         // letter badge if no icon
    );

    setState(() {
      _items.add(cat);
      _sortItems();
    });
    _openSpace(cat);
  }

  Future<void> _longPressSpace(CategoryItem it) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(it.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: _electricBlue),
            title: Text(it.pinned ? "Unpin" : "Pin"),
            onTap: () => Navigator.pop(context, 'pin'),
          ),
          if (it.isCustom)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text("Delete (custom space)"),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (action == 'pin') {
      setState(() {
        it.pinned = !it.pinned;
        _sortItems();
      });
    } else if (action == 'delete' && it.isCustom) {
      setState(() {
        _items.removeWhere((e) => e.id == it.id);
      });
    }
  }

  void _handleToolTap(String id) {
    widget.onTapTool?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.padding.bottom + 24 + 96;

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad),
            children: [
              _CategoryScroller(items: _items, onTap: _openSpace, onLongPress: _longPressSpace),
              const SizedBox(height: 12),
              const _SectionHeader("Spaces"),
              const SizedBox(height: 8),
              _CategoryGrid(items: _items, onTap: _openSpace, onLongPress: _longPressSpace),
              const SizedBox(height: 18),
              const _SectionHeader("Advanced Spaces"),
              const SizedBox(height: 8),
              _ToolGrid(items: _tools, onTap: _handleToolTap),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: _FloatingAdd(onTap: _createSpaceFlow),
          ),
        ],
      ),
    );
  }
}

/* ───────── utilities / visuals ───────── */

Color _mix(Color a, Color b, double t) => Color.fromARGB(
  (a.alpha + (b.alpha - a.alpha) * t).round(),
  (a.red + (b.red - a.red) * t).round(),
  (a.green + (b.green - a.green) * t).round(),
  (a.blue + (b.blue - a.blue) * t).round(),
);

Color _adaptiveBorder(BuildContext ctx) {
  final cs = Theme.of(ctx).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  return (isDark ? _electricBlue : Colors.black87).withOpacity(isDark ? .35 : .18);
}

List<BoxShadow> _iconHalo(BuildContext ctx, Color color) {
  final cs = Theme.of(ctx).colorScheme;
  final isDark = cs.brightness == Brightness.dark;
  return isDark ? [BoxShadow(color: color.withOpacity(.35), blurRadius: 10, spreadRadius: .6)] : [];
}

List<Color> _badgeGradient(BuildContext ctx, List<Color> accent) {
  final cs = Theme.of(ctx).colorScheme;
  final base = cs.surface;
  final isDark = cs.brightness == Brightness.dark;
  return [_mix(base, accent.first, isDark ? .12 : .22), _mix(base, accent.last, isDark ? .06 : .12)];
}

Color _pillBg(BuildContext ctx, {bool selected = false}) {
  final cs = Theme.of(ctx).colorScheme;
  return selected ? (cs.brightness == Brightness.dark ? _electricBlue : cs.primary)
                  : cs.surfaceVariant.withOpacity(.24);
}

/* ───────── HEADER ───────── */

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Row(children: [
      Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
        color: isLight ? Colors.black : Colors.white)),
    ]);
  }
}

/* ───────── categories ───────── */

class CategoryItem {
  final String id; final String title;
  final IconData? icon;              // can be null for letter badges
  final List<Color> accent; final Color iconColor;
  final bool isCustom; // shows delete on long-press in Explore
  bool pinned;         // pin/unpin in Explore
  final String? letter;

  CategoryItem(this.id, this.title, this.icon, this.accent, this.iconColor,
      {this.isCustom = false, this.pinned = false, this.letter});
}

/// BUILT-IN SPACES (Productivity removed)
final List<CategoryItem> _builtin = [
  CategoryItem("education", "Education", Icons.school_rounded,
      [_electricBlue, const Color(0xFF7E57C2)], const Color(0xFF7E57C2)),
  CategoryItem("email", "Email", Icons.email_rounded,
      [_electricBlue, const Color(0xFF6EE7B7)], const Color(0xFF42A5F5)),
  CategoryItem("work", "Work", Icons.work_outline_rounded,
      [_electricBlue, const Color(0xFFFFB74D)], const Color(0xFFFFA726)),
  CategoryItem("social", "Social media", Icons.share_rounded,
      [_electricBlue, const Color(0xFF7C4DFF)], const Color(0xFF26C6DA)),
  CategoryItem("marketing", "Marketing", Icons.campaign_rounded,
      [_electricBlue, const Color(0xFFFF8A65)], const Color(0xFFFF7043)),
  CategoryItem("lifestyle", "Lifestyle", Icons.fitness_center_rounded,
      [_electricBlue, const Color(0xFFFF7043)], const Color(0xFFFF7043)),
  CategoryItem("communication", "Communication", Icons.forum_rounded,
      [_electricBlue, const Color(0xFF81C784)], const Color(0xFF66BB6A)),
  CategoryItem("ideas", "Ideas", Icons.lightbulb_outline_rounded,
      [_electricBlue, const Color(0xFFFFD54F)], const Color(0xFFFFC107)),
  CategoryItem("fun", "Fun", Icons.emoji_emotions_rounded,
      [_electricBlue, const Color(0xFF9575CD)], const Color(0xFFFFEE58)),
  CategoryItem("health", "Health", Icons.favorite_border_rounded,
      [_electricBlue, const Color(0xFFE57373)], const Color(0xFFE57373)),
  CategoryItem("cooking", "Cooking", Icons.restaurant_menu_rounded,
      [_electricBlue, const Color(0xFFFFC107)], const Color(0xFFFFC107)),
  CategoryItem("greetings", "Greetings", Icons.favorite_rounded,
      [_electricBlue, const Color(0xFFFF80AB)], const Color(0xFFE53935)),
];

class _CategoryScroller extends StatefulWidget {
  final List<CategoryItem> items;
  final void Function(CategoryItem it)? onTap;
  final void Function(CategoryItem it)? onLongPress;
  const _CategoryScroller({required this.items, this.onTap, this.onLongPress});

  @override
  State<_CategoryScroller> createState() => _CategoryScrollerState();
}

class _CategoryScrollerState extends State<_CategoryScroller> {
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        itemCount: widget.items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _pill(context, "All", selected: true, onTap: () {});
          }
          final it = widget.items[i - 1];
          return GestureDetector(
            onLongPress: () => widget.onLongPress?.call(it),
            child: _pill(context, it.title, onTap: () => widget.onTap?.call(it)),
          );
        },
      ),
    );
  }

  Widget _pill(BuildContext ctx, String text, {bool selected = false, VoidCallback? onTap}) {
    final cs = Theme.of(ctx).colorScheme;
    final bg = _pillBg(ctx, selected: selected);
    final fg = selected ? (cs.brightness == Brightness.dark ? Colors.black : Colors.white)
                        : (cs.brightness == Brightness.dark ? cs.onSurface : Colors.black87);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _adaptiveBorder(ctx)),
        ),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/* ───────── grid badges ───────── */

class _CategoryGrid extends StatelessWidget {
  final List<CategoryItem> items;
  final void Function(CategoryItem it)? onTap;
  final void Function(CategoryItem it)? onLongPress;
  const _CategoryGrid({required this.items, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisExtent: 120, crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) {
        final item = items[i];
        return GestureDetector(
          onTap: () => onTap?.call(item),
          onLongPress: () => onLongPress?.call(item),
          child: _AdaptiveBadge(item: item),
        );
      },
    );
  }
}

class _AdaptiveBadge extends StatelessWidget {
  final CategoryItem item;
  const _AdaptiveBadge({required this.item});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grad = _badgeGradient(context, item.accent);
    final ring = _adaptiveBorder(context);
    final fg = cs.brightness == Brightness.light ? Colors.black : cs.onSurface;

    Widget glyph() {
      if (item.icon != null) {
        return Container(
          decoration: BoxDecoration(boxShadow: _iconHalo(context, item.iconColor)),
          child: Icon(item.icon, size: 28, color: item.iconColor),
        );
      }
      return Text(
        (item.letter ?? item.title.substring(0, 1)).toUpperCase(),
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cs.onSurface),
      );
    }

    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: ring, width: 1.2),
          ),
          child: Center(child: glyph()),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.pinned) const Icon(Icons.push_pin_rounded, size: 12),
            Flexible(
              child: Text(item.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: fg)),
            ),
          ],
        ),
      ],
    );
  }
}

/* ───────── tools grid ───────── */

class ToolItem {
  final String id; final String title; final IconData icon; final List<Color> accent; final Color iconColor;
  const ToolItem(this.id, this.title, this.icon, this.accent, this.iconColor);
}

/// NOTE: Removed “AI Keyboard”, “Bubble AI”, and **Storytelling** as requested.
const List<ToolItem> _tools = [
  ToolItem("solve_math", "Solve Math", Icons.calculate_rounded, [_electricBlue, Color(0xFF90CAF9)], Color(0xFF42A5F5)),
  ToolItem("upload_ask", "Upload Image & Ask", Icons.upload_file_rounded, [_electricBlue, Color(0xFF7E57C2)], Color(0xFF7E57C2)),
  ToolItem("homework", "AI Homework Tutor", Icons.menu_book_rounded, [_electricBlue, Color(0xFFFF8A65)], Color(0xFFFF7043)),
  ToolItem("pdf_summary", "PDF summary & Ask", Icons.picture_as_pdf_rounded, [_electricBlue, Color(0xFFE57373)], Color(0xFFE57373)),
  ToolItem("email_writer", "AI Email Writer", Icons.mail_outline_rounded, [_electricBlue, Color(0xFF64B5F6)], Color(0xFF1E88E5)),
  ToolItem("deepsearch", "AI DeepSearch", Icons.search_rounded, [_electricBlue, Color(0xFFFF7043)], Color(0xFFFF7043)),
  ToolItem("ocr", "OCR", Icons.document_scanner_rounded, [_electricBlue, Color(0xFFFFB74D)], Color(0xFFF57C00)),
  ToolItem("ask_url", "Ask about URL", Icons.language_rounded, [_electricBlue, Color(0xFFBA68C8)], Color(0xFF8E24AA)),
  ToolItem("yt_summary", "Youtube Summary & Ask", Icons.ondemand_video_rounded, [_electricBlue, Color(0xFFE57373)], Color(0xFFD32F2F)),
  ToolItem("grammar", "Grammar Check", Icons.spellcheck_rounded, [_electricBlue, Color(0xFF81C784)], Color(0xFF43A047)),
  ToolItem("translation", "AI Translation", Icons.translate_rounded, [_electricBlue, Color(0xFFFFD54F)], Color(0xFFF9A825)),
  ToolItem("travel_tool", "Travel", Icons.flight_takeoff_rounded, [_electricBlue, Color(0xFF64B5F6)], Color(0xFF1E88E5)),
];

class _ToolGrid extends StatelessWidget {
  final List<ToolItem> items;
  final ValueChanged<String>? onTap;
  const _ToolGrid({required this.items, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = _adaptiveBorder(context);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true, itemCount: items.length, padding: const EdgeInsets.only(top: 6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, mainAxisExtent: 126, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemBuilder: (_, i) {
        final it = items[i];
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onTap?.call(it.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: _badgeGradient(context, it.accent), begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surface.withOpacity(.06), border: Border.all(color: border)),
                child: Center(child: Container(
                  decoration: BoxDecoration(boxShadow: _iconHalo(context, it.iconColor)),
                  child: Icon(it.icon, size: 24, color: it.iconColor),
                ))),
              const SizedBox(height: 10),
              Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ]),
          ),
        );
      },
    );
  }
}

/* ───────── floating add ───────── */

class _FloatingAdd extends StatelessWidget {
  final VoidCallback onTap;
  const _FloatingAdd({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ring = cs.onSurface.withOpacity(.5);
    return GestureDetector(
      onTap: onTap,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 74, height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: cs.surfaceVariant.withOpacity(.18),
            border: Border.all(color: ring, width: 1.2),
          ),
        ),
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.brightness == Brightness.dark ? _electricBlue : cs.primary,
            border: Border.all(color: cs.onPrimary.withOpacity(.25), width: 1.2),
          ),
          child: Icon(Icons.add, color: cs.brightness == Brightness.dark ? Colors.black : cs.onPrimary, size: 28),
        ),
      ]),
    );
  }
}

/* ───────── Create Space sheet ───────── */

class _NewSpaceResult {
  final String name;
  final IconData? icon; // nullable now
  const _NewSpaceResult(this.name, this.icon);
}

class _CreateSpaceSheet extends StatefulWidget {
  const _CreateSpaceSheet();
  @override
  State<_CreateSpaceSheet> createState() => _CreateSpaceSheetState();
}

class _CreateSpaceSheetState extends State<_CreateSpaceSheet> {
  final _name = TextEditingController();
  IconData? _picked;

  final List<IconData> _iconChoices = const [
    Icons.school_rounded,
    Icons.email_rounded,
    Icons.work_outline_rounded,
    Icons.share_rounded,
    Icons.campaign_rounded,
    Icons.fitness_center_rounded,
    Icons.forum_rounded,
    Icons.lightbulb_outline_rounded,
    Icons.emoji_emotions_rounded,
    Icons.favorite_border_rounded,
    Icons.restaurant_menu_rounded,
    Icons.favorite_rounded,
    Icons.flight_takeoff_rounded,
    Icons.translate_rounded,
    Icons.search_rounded,
  ];

  Future<void> _pickIcon() async {
    final choice = await showModalBottomSheet<IconData>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GridView.builder(
            itemCount: _iconChoices.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10, mainAxisExtent: 56),
            itemBuilder: (_, i) {
              final ic = _iconChoices[i];
              final active = _picked == ic;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(ctx, ic),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: active ? cs.primary : _adaptiveBorder(ctx), width: active ? 2 : 1.2),
                    color: cs.surfaceVariant.withOpacity(.12),
                  ),
                  child: Center(child: Icon(ic, color: active ? cs.primary : cs.onSurface)),
                ),
              );
            },
          ),
        );
      },
    );
    if (choice != null) setState(() => _picked = choice);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ring = _adaptiveBorder(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16, right: 16, top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text("Create Space", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Icon preview / letter (tap to choose, but optional)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickIcon,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ring),
                    color: cs.surfaceVariant.withOpacity(.12),
                  ),
                  child: Center(
                    child: Icon(_picked ?? Icons.apps_rounded,
                        size: 26,
                        color: _picked == null ? cs.onSurface.withOpacity(.6) : cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: "Space name",
                    hintText: "e.g. Startup Ideas",
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(context, _NewSpaceResult(name, _picked)); // icon can be null
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Tip: long-press a space to pin it. Custom spaces can be deleted. Icon is optional.",
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(.7)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  final name = _name.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context, _NewSpaceResult(name, _picked));
                },
                style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: Colors.black),
                child: const Text("Create"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
