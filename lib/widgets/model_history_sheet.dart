import 'package:flutter/material.dart';

import '../models/media_result.dart';
import '../services/media_history_store.dart';
import '../services/provider_branding.dart';
import 'media_result_card.dart';

class ModelHistorySheet extends StatefulWidget {
  final String category;
  final String modelId;
  final String title;

  const ModelHistorySheet({
    super.key,
    required this.category,
    required this.modelId,
    required this.title,
  });

  @override
  State<ModelHistorySheet> createState() => _ModelHistorySheetState();
}

class _ModelHistorySheetState extends State<ModelHistorySheet> {
  final MediaHistoryStore _store = MediaHistoryStore();

  bool _loading = true;
  bool _selectionMode = false;
  List<GeneratedMediaItem> _items = [];
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _itemKey(GeneratedMediaItem item) {
    final prediction = item.predictionId?.trim() ?? '';
    if (prediction.isNotEmpty) return 'pred:$prediction';
    return 'url:${item.previewUrl}|model:${item.modelId}|ts:${item.createdAt.toIso8601String()}';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final filtered = await _store.loadByCategoryAndModel(widget.category, widget.modelId);
    if (!mounted) return;
    setState(() {
      _items = filtered;
      _loading = false;
    });
  }

  void _toggleSelection(GeneratedMediaItem item) {
    final key = _itemKey(item);
    setState(() {
      _selectionMode = true;
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  Future<void> _rename(GeneratedMediaItem item) async {
    final ctrl = TextEditingController(text: item.metadata['customTitle']?.toString() ?? item.modelName);
    final next = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename item'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (next == null || next.trim().isEmpty) return;
    await _store.renameItem(item, next.trim());
    await _load();
  }

  Future<void> _togglePin(GeneratedMediaItem item) async {
    await _store.togglePinned(item);
    await _load();
  }

  Future<void> _delete(GeneratedMediaItem item) async {
    await _store.deleteItem(item);
    await _load();
  }

  Future<void> _deleteSelected() async {
    final targets = _items.where((e) => _selected.contains(_itemKey(e))).toList(growable: false);
    if (targets.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete history?'),
        content: Text('Delete ${targets.length} selected item(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    for (final item in targets) {
      await _store.deleteItem(item);
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
    await _load();
  }

  Future<void> _clearAllForModel() async {
    await _store.clearByCategoryAndModel(widget.category, widget.modelId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _items.isNotEmpty
        ? ProviderBranding.resolve(provider: _items.first.provider, modelId: _items.first.modelId, displayName: _items.first.modelName).accent
        : const Color(0xFF00B8FF);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          children: [
            Row(
              children: [
                if (_selectionMode)
                  IconButton(
                    onPressed: () => setState(() {
                      _selectionMode = false;
                      _selected.clear();
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                Expanded(
                  child: Text(
                    _selectionMode ? '${_selected.length} selected' : widget.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                if (_items.isNotEmpty && !_selectionMode)
                  TextButton.icon(
                    onPressed: _clearAllForModel,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Clear all'),
                  ),
                if (_selectionMode) ...[
                  IconButton(
                    onPressed: () => setState(() {
                      if (_selected.length == _items.length) {
                        _selected.clear();
                        _selectionMode = false;
                      } else {
                        _selected
                          ..clear()
                          ..addAll(_items.map(_itemKey));
                      }
                    }),
                    icon: const Icon(Icons.select_all_rounded),
                  ),
                  IconButton(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('No history for this model yet.'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            final pinned = item.metadata['pinned'] == true;
                            final selected = _selected.contains(_itemKey(item));

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onLongPress: () => _toggleSelection(item),
                                onTap: _selectionMode ? () => _toggleSelection(item) : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: selected ? accent.withOpacity(.72) : (isLight ? Colors.black12 : Colors.white12),
                                      width: selected ? 1.4 : 1,
                                    ),
                                    gradient: LinearGradient(colors: [accent.withOpacity(isLight ? .10 : .14), Colors.transparent]),
                                  ),
                                  child: Column(
                                    children: [
                                      if (_selectionMode)
                                        ListTile(
                                          leading: Checkbox(value: selected, onChanged: (_) => _toggleSelection(item)),
                                          title: Text(item.metadata['customTitle']?.toString() ?? item.modelName),
                                          subtitle: Text(item.prompt, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        )
                                      else
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'rename') await _rename(item);
                                              if (value == 'pin') await _togglePin(item);
                                              if (value == 'delete') await _delete(item);
                                            },
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(value: 'rename', child: Text('Rename')),
                                              PopupMenuItem(value: 'pin', child: Text(pinned ? 'Unpin' : 'Pin')),
                                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                            ],
                                          ),
                                        ),
                                      if (!_selectionMode && pinned)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 14, bottom: 4),
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Icon(Icons.push_pin_rounded, size: 18, color: accent),
                                          ),
                                        ),
                                      IgnorePointer(
                                        ignoring: _selectionMode,
                                        child: MediaResultCard(
                                          key: ValueKey('${item.predictionId ?? item.previewUrl}-${item.createdAt.microsecondsSinceEpoch}'),
                                          item: item,
                                          onDelete: () => _delete(item),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
