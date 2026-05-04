import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/media_result.dart';
import '../services/media_file_service.dart';
import '../services/research_canvas_store.dart';
import 'save_to_canvas_sheet.dart';
import 'media_fullscreen_viewer.dart';

bool _isRemoteMediaPath(String raw) =>
    raw.startsWith('http://') || raw.startsWith('https://') || raw.startsWith('data:');

class MediaResultCard extends StatelessWidget {
  final GeneratedMediaItem item;
  final VoidCallback? onRegenerate;
  final VoidCallback? onEdit;
  final VoidCallback? onUseAsPrompt;
  final VoidCallback? onDelete;

  const MediaResultCard({
    super.key,
    required this.item,
    this.onRegenerate,
    this.onEdit,
    this.onUseAsPrompt,
    this.onDelete,
  });

  String get _displayTitle => MediaFileService.displayTitle(item);

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final scheme = Theme.of(context).colorScheme;
    final heroTag =
        'media-${item.createdAt.microsecondsSinceEpoch}-${item.modelId}-${item.url.hashCode}';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outline.withOpacity(.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewSection(
              item: item,
              heroTag: heroTag,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaChip(
                  icon: _typeIcon(item.mediaType),
                  label: item.typeLabel,
                ),
                if (item.pointsCost > 0)
                  _MetaChip(
                    icon: Icons.bolt_rounded,
                    label: '${item.pointsCost} pts',
                  ),
                _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: _timeLabel(item.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _displayTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                height: 1.15,
              ),
            ),
            if (_displayTitle.trim().toLowerCase() !=
                item.modelName.trim().toLowerCase()) ...[
              const SizedBox(height: 6),
              Text(
                item.modelName,
                style: TextStyle(
                  color: scheme.onSurface.withOpacity(.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              item.prompt,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isLight ? Colors.black54 : Colors.white70,
                height: 1.4,
              ),
            ),
            if (item.hasMultipleOutputs) ...[
              const SizedBox(height: 10),
              Text(
                '${item.normalizedUrls.length} outputs generated',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionPill(
                  icon: item.isAudio
                      ? Icons.play_circle_fill_rounded
                      : item.isVideo
                          ? Icons.ondemand_video_rounded
                          : Icons.open_in_new_rounded,
                  label: item.isImage
                      ? 'Preview'
                      : item.isAudio
                          ? 'Player'
                          : item.isVideo
                              ? 'Watch'
                              : 'Open',
                  onTap: () => _openPrimary(context, item, heroTag),
                ),
                _ActionPill(
                  icon: Icons.download_rounded,
                  label: 'Save',
                  onTap: () async {
                    try {
                      final path = await MediaFileService.downloadAndGetPath(item);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved to: $path')),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                      );
                    }
                  },
                ),
                _ActionPill(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: () => _runAction(
                    context,
                    () => MediaFileService.shareItem(item),
                    'Shared',
                  ),
                ),
                _ActionPill(
                  icon: Icons.copy_all_rounded,
                  label: 'Copy link',
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: item.previewUrl),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    }
                  },
                ),
                _ActionPill(
                  icon: Icons.auto_awesome_mosaic_rounded,
                  label: 'Canvas',
                  onTap: () {
                    final canvasMediaUrl = _bestCanvasPrimaryUrl(item);
                    final canvasThumbUrl = _bestCanvasThumbnailUrl(item);
                    SaveToCanvasSheet.open(
                      context,
                      draft: ResearchCanvasBlockDraft(
                        type: item.typeKey,
                        title: _displayTitle,
                        question: item.prompt,
                        content: item.prompt,
                        sourceLabel: '${item.typeLabel} result',
                        modelLabel: item.modelName,
                        tags: const <String>[],
                        mediaUrl: canvasMediaUrl,
                        thumbnailUrl: item.isAudio ? null : canvasThumbUrl,
                        extra: <String, dynamic>{
                          'sourceUrl': canvasMediaUrl,
                          'sourceType': item.typeKey,
                          'previewUrl': item.previewUrl,
                          'mimeType': item.mimeType,
                          'mediaType': item.typeKey,
                          'allUrls': item.normalizedUrls,
                          'mediaCandidates': _canvasMediaCandidates(item),
                          'videoUrl': item.isVideo ? canvasMediaUrl : null,
                          'audioUrl': item.isAudio ? canvasMediaUrl : null,
                          'imageUrl': item.isImage ? canvasMediaUrl : canvasThumbUrl,
                          'thumbnailUrl': canvasThumbUrl,
                          'canvasMediaUrl': canvasMediaUrl,
                          'canvasThumbnailUrl': canvasThumbUrl,
                        },
                      ),
                    );
                  },
                ),
                if (onRegenerate != null)
                  _ActionPill(
                    icon: Icons.refresh_rounded,
                    label: 'Regenerate',
                    onTap: onRegenerate!,
                  ),
                if (onDelete != null)
                  _ActionPill(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    onTap: onDelete!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _typeIcon(GeneratedMediaType type) {
    switch (type) {
      case GeneratedMediaType.image:
        return Icons.image_rounded;
      case GeneratedMediaType.video:
        return Icons.videocam_rounded;
      case GeneratedMediaType.audio:
        return Icons.graphic_eq_rounded;
      case GeneratedMediaType.unknown:
        return Icons.insert_drive_file_rounded;
    }
  }

  static List<String> _canvasMediaCandidates(GeneratedMediaItem item) {
    final candidates = <String>[];

    void add(dynamic value) {
      if (value == null) return;
      if (value is List) {
        for (final entry in value) {
          add(entry);
        }
        return;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty && !candidates.contains(text)) {
        candidates.add(text);
      }
    }

    add(item.localFilePath);
    add(item.url);
    add(item.previewUrl);
    add(item.normalizedUrls);

    const extraKeys = [
      'videoUrl',
      'audioUrl',
      'imageUrl',
      'mediaUrl',
      'thumbnailUrl',
      'thumbUrl',
      'posterUrl',
      'previewImageUrl',
      'sourceUrl',
      'previewUrl',
      'outputUrl',
      'downloadUrl',
      'fileUrl',
      'playbackUrl',
      'localFilePath',
      'allUrls',
      'mediaCandidates',
      'videoCandidates',
      'audioCandidates',
      'imageCandidates',
    ];
    for (final key in extraKeys) {
      add(item.metadata[key]);
    }

    return candidates;
  }

  static bool _urlLooksLikeType(String url, GeneratedMediaType type) {
    final lower = url.toLowerCase();
    final bare = lower.split('#').first.split('?').first;
    final hints = Uri.tryParse(url)?.queryParametersAll.values.expand((e) => e).join(' ').toLowerCase() ?? '';
    switch (type) {
      case GeneratedMediaType.video:
        return bare.endsWith('.mp4') ||
            bare.endsWith('.mov') ||
            bare.endsWith('.webm') ||
            bare.endsWith('.mkv') ||
            bare.endsWith('.m4v') ||
            lower.contains('video/mp4') ||
            lower.contains('video%2f') ||
            lower.contains('response-content-type=video') ||
            lower.contains('content-type=video') ||
            lower.contains('mime=video') ||
            lower.contains('/video/') ||
            hints.contains('video');
      case GeneratedMediaType.audio:
        return bare.endsWith('.mp3') ||
            bare.endsWith('.wav') ||
            bare.endsWith('.m4a') ||
            bare.endsWith('.aac') ||
            bare.endsWith('.ogg') ||
            bare.endsWith('.flac') ||
            lower.contains('audio/') ||
            lower.contains('audio%2f') ||
            lower.contains('response-content-type=audio') ||
            lower.contains('content-type=audio') ||
            lower.contains('mime=audio') ||
            hints.contains('audio');
      case GeneratedMediaType.image:
        return bare.endsWith('.png') ||
            bare.endsWith('.jpg') ||
            bare.endsWith('.jpeg') ||
            bare.endsWith('.webp') ||
            bare.endsWith('.gif') ||
            lower.contains('image/') ||
            lower.contains('image%2f') ||
            lower.contains('response-content-type=image') ||
            lower.contains('content-type=image') ||
            lower.contains('mime=image') ||
            hints.contains('image');
      case GeneratedMediaType.unknown:
        return false;
    }
  }

  static bool _looksLikeThumbnail(String url) {
    final lower = url.toLowerCase();
    return lower.contains('thumb') ||
        lower.contains('thumbnail') ||
        lower.contains('poster') ||
        lower.contains('preview-image') ||
        lower.contains('preview_image');
  }

  static String _bestCanvasPrimaryUrl(GeneratedMediaItem item) {
    final candidates = _canvasMediaCandidates(item);
    for (final candidate in candidates) {
      if (_urlLooksLikeType(candidate, item.mediaType)) return candidate;
    }

    if (item.isVideo) {
      for (final candidate in candidates) {
        if (!_urlLooksLikeType(candidate, GeneratedMediaType.image) && !_looksLikeThumbnail(candidate)) {
          return candidate;
        }
      }
    }

    if (item.isAudio) {
      for (final candidate in candidates) {
        if (!_urlLooksLikeType(candidate, GeneratedMediaType.image) && !_urlLooksLikeType(candidate, GeneratedMediaType.video)) {
          return candidate;
        }
      }
    }

    return candidates.isEmpty ? item.previewUrl : candidates.first;
  }

  static String? _bestCanvasThumbnailUrl(GeneratedMediaItem item) {
    if (item.isAudio) return null;
    final candidates = _canvasMediaCandidates(item);
    if (item.isImage) {
      return candidates.isEmpty ? item.previewUrl : candidates.first;
    }
    for (final candidate in candidates) {
      if (_urlLooksLikeType(candidate, GeneratedMediaType.image) || _looksLikeThumbnail(candidate)) {
        return candidate;
      }
    }
    return candidates.isEmpty ? null : candidates.first;
  }

  static String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  static Future<void> _openPrimary(
    BuildContext context,
    GeneratedMediaItem item,
    String heroTag,
  ) async {
    if (item.isImage) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaFullscreenViewer(
            url: item.previewUrl,
            heroTag: heroTag,
          ),
        ),
      );
      return;
    }

    if (item.isAudio) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: _AudioPlayerSheet(
            title: MediaFileService.displayTitle(item),
            url: item.previewUrl,
          ),
        ),
      );
      return;
    }

    if (item.isVideo) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _VideoPlayerPage(
            title: MediaFileService.displayTitle(item),
            url: item.previewUrl,
          ),
        ),
      );
      return;
    }

    await _openExternally(item.previewUrl);
  }

  static Future<void> _openExternally(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _PreviewSection extends StatelessWidget {
  final GeneratedMediaItem item;
  final String heroTag;

  const _PreviewSection({
    required this.item,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MediaFullscreenViewer(
                  url: item.previewUrl,
                  heroTag: heroTag,
                ),
              ),
            );
          },
          child: AspectRatio(
            aspectRatio: 1,
            child: Hero(
              tag: heroTag,
              child: _isRemoteMediaPath(item.previewUrl)
                  ? Image.network(
                      item.previewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _FallbackPreview(
                        icon: Icons.image_not_supported_rounded,
                        title: 'Image preview unavailable',
                        subtitle: item.previewUrl,
                      ),
                    )
                  : Image.file(
                      File(item.previewUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _FallbackPreview(
                        icon: Icons.image_not_supported_rounded,
                        title: 'Image preview unavailable',
                        subtitle: item.previewUrl,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    if (item.isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _VideoPlayerPage(
                  title: MediaFileService.displayTitle(item),
                  url: item.previewUrl,
                ),
              ),
            );
          },
          child: _InlineVideoPreview(
            key: ValueKey(item.previewUrl),
            url: item.previewUrl,
            title: MediaFileService.displayTitle(item),
          ),
        ),
      );
    }

    if (item.isAudio) {
      return _InlineAudioPlayer(
        title: MediaFileService.displayTitle(item),
        url: item.previewUrl,
      );
    }

    return _FallbackPreview(
      icon: Icons.insert_drive_file_rounded,
      title: 'Preview unavailable',
      subtitle: item.previewUrl,
    );
  }
}

class _InlineVideoPreview extends StatefulWidget {
  final String url;
  final String title;

  const _InlineVideoPreview({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<_InlineVideoPreview> createState() => _InlineVideoPreviewState();
}

class _InlineVideoPreviewState extends State<_InlineVideoPreview> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _InlineVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resetAndInit();
    }
  }
Future<void> _resetAndInit() async {
    final previous = _controller;
    if (previous != null) {
      previous.removeListener(_sync);
      await previous.dispose();
    }
    if (!mounted) return;
    setState(() {
      _controller = null;
      _loading = true;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    await _init();
  }

  Future<void> _init() async {
    try {
      final controller = _isRemoteMediaPath(widget.url)
          ? VideoPlayerController.networkUrl(Uri.parse(widget.url))
          : VideoPlayerController.file(File(widget.url));
      await controller.initialize();
      controller.addListener(_sync);
      setState(() {
        _controller = controller;
        _duration = controller.value.duration;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _sync() {
    final c = _controller;
    if (c == null || !mounted) return;
    setState(() {
      _position = c.value.position;
      _duration = c.value.duration;
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_sync);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
  }

  Future<void> _seek(double value) async {
    final c = _controller;
    if (c == null) return;
    await c.seekTo(Duration(milliseconds: value.round()));
  }

  String _fmt(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(1, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;

    if (_loading) {
      return Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: scheme.surfaceVariant.withOpacity(.35),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_error != null || controller == null || !controller.value.isInitialized) {
      return _FallbackPreview(
        icon: Icons.videocam_off_rounded,
        title: 'Video preview unavailable',
        subtitle: _error ?? widget.url,
      );
    }

    final maxMs = _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds;
    final posMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio == 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: VideoPlayer(controller),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Slider(
                      value: posMs,
                      min: 0,
                      max: maxMs.toDouble(),
                      onChanged: _seek,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_fmt(_position)} / ${_fmt(_duration)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          onPressed: _togglePlay,
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ],
                    ),
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

class _InlineAudioPlayer extends StatefulWidget {
  final String title;
  final String url;

  const _InlineAudioPlayer({
    required this.title,
    required this.url,
  });

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  late final AudioPlayer _player;

  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.completed;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.play(
          _isRemoteMediaPath(widget.url)
              ? UrlSource(widget.url)
              : DeviceFileSource(widget.url),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seek(double value) async {
    await _player.seek(Duration(milliseconds: value.round()));
  }

  String _fmt(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(1, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxMs = _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds;
    final posMs = _position.inMilliseconds.clamp(0, maxMs).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withOpacity(.16),
            scheme.secondary.withOpacity(.10),
            scheme.surfaceVariant.withOpacity(.45),
          ],
        ),
        border: Border.all(
          color: scheme.outline.withOpacity(.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(.18),
                ),
                child: IconButton(
                  onPressed: _loading ? null : _togglePlay,
                  icon: Icon(
                    _playerState == PlayerState.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Slider(
            value: posMs,
            min: 0,
            max: maxMs.toDouble(),
            onChanged: (v) => _seek(v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(_position),
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                _fmt(_duration),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          if (_error != null && _error!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AudioPlayerSheet extends StatelessWidget {
  final String title;
  final String url;

  const _AudioPlayerSheet({
    required this.title,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        _InlineAudioPlayer(
          title: title,
          url: url,
        ),
      ],
    );
  }
}

class _FallbackPreview extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FallbackPreview({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceVariant.withOpacity(.45),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 42,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.primary.withOpacity(.08),
        border: Border.all(
          color: scheme.primary.withOpacity(.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: scheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: scheme.surfaceVariant.withOpacity(.35),
          border: Border.all(
            color: scheme.outline.withOpacity(.10),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPlayerPage extends StatefulWidget {
  final String title;
  final String url;

  const _VideoPlayerPage({
    required this.title,
    required this.url,
  });

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }Future<void> _resetAndInit() async {
    final previous = _controller;
    if (previous != null) {
      previous.removeListener(_sync);
      await previous.dispose();
    }
    if (!mounted) return;
    setState(() {
      _controller = null;
      _loading = true;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    await _init();
  }

  Future<void> _init() async {
    try {
      final controller = _isRemoteMediaPath(widget.url)
          ? VideoPlayerController.networkUrl(Uri.parse(widget.url))
          : VideoPlayerController.file(File(widget.url));
      await controller.initialize();
      controller.addListener(_sync);
      setState(() {
        _controller = controller;
        _duration = controller.value.duration;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _sync() {
    final c = _controller;
    if (c == null || !mounted) return;
    setState(() {
      _position = c.value.position;
      _duration = c.value.duration;
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_sync);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
  }

  Future<void> _seek(double value) async {
    final c = _controller;
    if (c == null) return;
    await c.seekTo(Duration(milliseconds: value.round()));
  }

  String _fmt(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString();
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null || controller == null || !controller.value.isInitialized)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error ?? 'Video failed to load',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio == 0
                              ? 16 / 9
                              : controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Column(
                        children: [
                          Slider(
                            value: _position.inMilliseconds
                                .clamp(
                                  0,
                                  _duration.inMilliseconds <= 0
                                      ? 1
                                      : _duration.inMilliseconds,
                                )
                                .toDouble(),
                            min: 0,
                            max: (_duration.inMilliseconds <= 0
                                    ? 1
                                    : _duration.inMilliseconds)
                                .toDouble(),
                            onChanged: _seek,
                          ),
                          Row(
                            children: [
                              Text(_fmt(_position)),
                              const Spacer(),
                              Text(_fmt(_duration)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _togglePlay,
                            icon: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(
                              controller.value.isPlaying ? 'Pause' : 'Play',
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


