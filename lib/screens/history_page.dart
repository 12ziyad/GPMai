import 'package:flutter/material.dart';

import '../models/media_result.dart';
import '../services/media_history_store.dart';
import '../services/media_file_service.dart';
import '../services/sql_chat_store.dart';
import '../widgets/media_result_card.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  final SqlChatStore _chatStore = SqlChatStore();
  final MediaHistoryStore _mediaStore = MediaHistoryStore();
  final TextEditingController _search = TextEditingController();

  late final TabController _tabController;

  List<GeneratedMediaItem> _mediaItems = [];
  bool _loadingMedia = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    setState(() => _loadingMedia = true);
    try {
      final items = await _mediaStore.loadAll();
      if (!mounted) return;
      setState(() {
        _mediaItems = items;
        _loadingMedia = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMedia = false);
    }
  }


  Future<void> _deleteMediaItem(GeneratedMediaItem item) async {
    setState(() {
      _mediaItems.removeWhere((e) =>
          e.previewUrl == item.previewUrl &&
          e.modelId == item.modelId &&
          e.createdAt == item.createdAt);
    });

    await _mediaStore.deleteItem(item);
  }

  String _mediaTitle(GeneratedMediaItem item) {
    return MediaFileService.displayTitle(item);
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();

    final filteredMedia = _mediaItems.where((item) {
      if (q.isEmpty) return true;
      final hay = '${_mediaTitle(item)} ${item.modelName} ${item.prompt} ${item.category}'.toLowerCase();
      return hay.contains(q);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chats'),
            Tab(text: 'Media'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Search history',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                StreamBuilder<List<Chat>>(
                  stream: _chatStore.watchChats(),
                  builder: (context, snap) {
                    var items = snap.data ?? const <Chat>[];
                    if (q.isNotEmpty) {
                      items = items.where((m) => m.name.toLowerCase().contains(q)).toList();
                    }

                    if (items.isEmpty) {
                      return const Center(child: Text('No chats yet.'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final chat = items[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.chat_bubble_outline_rounded),
                            title: Text(chat.name),
                            subtitle: Text(
                              DateTime.fromMillisecondsSinceEpoch(chat.lastAt).toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                RefreshIndicator(
                  onRefresh: _loadMedia,
                  child: _loadingMedia
                      ? const Center(child: CircularProgressIndicator())
                      : filteredMedia.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 140),
                                Center(child: Text('No media history yet.')),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                              itemCount: filteredMedia.length,
                              itemBuilder: (_, i) {
                                final item = filteredMedia[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: MediaResultCard(
                                    key: ValueKey('${item.predictionId ?? item.previewUrl}-${item.createdAt.microsecondsSinceEpoch}'),
                                    item: item,
                                    onDelete: () => _deleteMediaItem(item),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
