import 'package:flutter/material.dart';

import '../services/curated_models.dart';
import '../services/provider_branding.dart';

class ModelHistoryItem {
  final String id;
  final String title;
  final String? subtitle;
  final DateTime? updatedAt;
  final bool pinned;

  const ModelHistoryItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.updatedAt,
    this.pinned = false,
  });
}

class ModelHistoryPage extends StatefulWidget {
  final CuratedModel model;
  final Future<List<ModelHistoryItem>> Function(String modelId) loadHistory;
  final void Function(ModelHistoryItem item)? onOpenHistoryItem;
  final Future<void> Function(String id, String newTitle)? onRename;
  final Future<void> Function(String id)? onDelete;
  final Future<void> Function(String id)? onTogglePin;

  const ModelHistoryPage({
    super.key,
    required this.model,
    required this.loadHistory,
    this.onOpenHistoryItem,
    this.onRename,
    this.onDelete,
    this.onTogglePin,
  });

  @override
  State<ModelHistoryPage> createState() => _ModelHistoryPageState();
}

class _ModelHistoryPageState extends State<ModelHistoryPage> {
  late Future<List<ModelHistoryItem>> _future;
  bool _selectionMode = false;
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.loadHistory(widget.model.id);
  }

  void _toggleSelection(String id) {
    setState(() {
      _selectionMode = true;
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  Future<void> _rename(ModelHistoryItem item) async {
    if (widget.onRename == null) return;
    final ctrl = TextEditingController(text: item.title);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Chat name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    await widget.onRename!(item.id, result.trim());
    setState(_reload);
  }

  Future<void> _togglePin(ModelHistoryItem item) async {
    if (widget.onTogglePin == null) return;
    await widget.onTogglePin!(item.id);
    setState(_reload);
  }

  Future<void> _deleteItems(List<ModelHistoryItem> items) async {
    if (widget.onDelete == null || items.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete chats?'),
        content: Text('Delete ${items.length} selected chat(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    for (final item in items) {
      await widget.onDelete!(item.id);
    }
    setState(() {
      _selectionMode = false;
      _selected.clear();
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brand = ProviderBranding.resolve(
      provider: widget.model.provider,
      modelId: widget.model.id,
      displayName: widget.model.displayName,
    );
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? const Color(0xFFF5F7FB) : const Color(0xFF090B11),
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selected.length} selected' : 'History'),
        leading: _selectionMode
            ? IconButton(
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selected.clear();
                }),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        actions: _selectionMode
            ? [
                IconButton(
                  onPressed: () async {
                    final items = await _future;
                    setState(() {
                      if (_selected.length == items.length) {
                        _selected.clear();
                        _selectionMode = false;
                      } else {
                        _selected
                          ..clear()
                          ..addAll(items.map((e) => e.id));
                      }
                    });
                  },
                  icon: const Icon(Icons.select_all_rounded),
                ),
                IconButton(
                  onPressed: () async {
                    final items = await _future;
                    await _deleteItems(items.where((e) => _selected.contains(e.id)).toList(growable: false));
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: FutureBuilder<List<ModelHistoryItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? const <ModelHistoryItem>[];
            if (items.isEmpty) {
              return Center(
                child: Text(
                  "You don't have any chats that include ${widget.model.displayName} yet.",
                  style: TextStyle(color: isLight ? Colors.black54 : Colors.white70),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              itemBuilder: (_, index) {
                final item = items[index];
                final selected = _selected.contains(item.id);
                return _HistoryTile(
                  item: item,
                  selected: selected,
                  selectionMode: _selectionMode,
                  accent: brand.accent,
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(item.id);
                    } else {
                      widget.onOpenHistoryItem?.call(item);
                    }
                  },
                  onLongPress: () => _toggleSelection(item.id),
                  onRename: () => _rename(item),
                  onTogglePin: () => _togglePin(item),
                  onDelete: () => _deleteItems([item]),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ModelHistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRename;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final bool selectionMode;
  final bool selected;
  final Color accent;

  const _HistoryTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onRename,
    required this.onTogglePin,
    required this.onDelete,
    required this.selectionMode,
    required this.selected,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final dateText = item.updatedAt == null
        ? null
        : '${item.updatedAt!.year}-${item.updatedAt!.month.toString().padLeft(2, '0')}-${item.updatedAt!.day.toString().padLeft(2, '0')}';
    return Material(
      color: isLight ? Colors.white : const Color(0xFF0D111A),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [accent.withOpacity(isLight ? .12 : .14), Colors.transparent],
            ),
            border: Border.all(color: selected ? accent.withOpacity(.72) : (isLight ? Colors.black12 : Colors.white10)),
          ),
          child: Row(
            children: [
              if (selectionMode)
                Checkbox(value: selected, onChanged: (_) => onTap())
              else
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withOpacity(.45)),
                  ),
                  child: Icon(Icons.chat_bubble_outline_rounded, color: accent),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                        ),
                        if (item.pinned) Icon(Icons.push_pin_rounded, size: 18, color: accent),
                      ],
                    ),
                    if ((item.subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isLight ? Colors.black54 : Colors.white70, fontSize: 14, height: 1.35)),
                    ],
                    if (dateText != null) ...[
                      const SizedBox(height: 8),
                      Text(dateText, style: TextStyle(color: isLight ? Colors.black45 : Colors.white54, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              if (!selectionMode)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'rename') onRename();
                    if (value == 'pin') onTogglePin();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'pin', child: Text(item.pinned ? 'Unpin' : 'Pin')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
