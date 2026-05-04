import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/media_result.dart';
import '../services/curated_media_models.dart';
import '../services/media_api.dart';
import '../services/media_history_store.dart';
import '../services/media_file_service.dart';
import '../services/media_input_helper.dart';
import '../widgets/media_result_card.dart';
import '../widgets/model_history_sheet.dart';

class ImageGeneratorPage extends StatefulWidget {
  final MediaModel? initialModel;

  const ImageGeneratorPage({
    super.key,
    this.initialModel,
  });

  @override
  State<ImageGeneratorPage> createState() => _ImageGeneratorPageState();
}

class _ImageGeneratorPageState extends State<ImageGeneratorPage> {
  final TextEditingController _promptController = TextEditingController();
  final MediaHistoryStore _historyStore = MediaHistoryStore();
  final MediaInputHelper _mediaInputHelper = MediaInputHelper();

  late MediaModel _selectedModel;

  final List<GeneratedMediaItem> _results = [];
  bool _isGenerating = false;

  PickedInputImage? _selectedInputImage;

  bool get _supportsImageInput => _selectedModel.supportsImageUpload;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.initialModel ?? imageModels.first;
    _loadSavedHistory();
    unawaited(_restoreActiveGeneration());
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    final picked = await showModalBottomSheet<MediaModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _SimpleMediaModelSheet(
        models: imageModels,
        selected: _selectedModel,
        title: 'Choose image model',
        subtitle: 'Pick a production-ready model for image generation or image-guided edits.',
      ),
    );

    if (picked == null) return;
    setState(() {
      _selectedModel = picked;
      if (!_supportsImageInput) {
        _selectedInputImage = null;
      }
    });
    _loadSavedHistory();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showSnack('Enter a prompt first');
      return;
    }
    if (_isGenerating) {
      _showSnack('An image is already generating. Please wait.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isGenerating = true);

    final input = <String, dynamic>{
      'aspect_ratio': '1:1',
      'quality': 'standard',
      'num_outputs': 1,
    };
    final inputUrls = _selectedInputImage == null ? const <String>[] : <String>[_selectedInputImage!.dataUrl];

    try {
      final startedAt = DateTime.now();
      final first = await MediaApi.startGeneration(
        MediaGenerationRequest(
          modelId: _selectedModel.id,
          category: 'image',
          prompt: prompt,
          input: input,
          inputUrls: inputUrls,
        ),
      );

      if (!first.processing) {
        await _handleCompletedResult(first, prompt: prompt, createdAt: startedAt);
        return;
      }

      final session = ActiveGenerationSession(
        category: 'image',
        modelId: _selectedModel.id,
        modelName: _selectedModel.name,
        prompt: prompt,
        predictionId: first.predictionId,
        startedAt: startedAt,
      );
      await _historyStore.saveActiveGeneration(session);
      await _resumeActiveGeneration(session);
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
        setState(() => _isGenerating = false);
      }
      await _historyStore.clearActiveGeneration('image');
    }
  }

  Future<void> _restoreActiveGeneration() async {
    final session = await _historyStore.loadActiveGeneration('image');
    if (session == null || !mounted) return;
    _promptController.text = session.prompt;
    final restoredModel = imageModels.where((m) => m.id == session.modelId).toList();
    setState(() {
      _isGenerating = true;
      if (restoredModel.isNotEmpty) {
        _selectedModel = restoredModel.first;
      }
    });
    await _resumeActiveGeneration(session);
  }

  Future<void> _resumeActiveGeneration(ActiveGenerationSession session) async {
    try {
      final result = await MediaApi.waitForCompletion(
        predictionId: session.predictionId,
        category: 'image',
        model: session.modelId,
      );
      await _handleCompletedResult(result, prompt: session.prompt, createdAt: session.startedAt);
    } catch (e) {
      await _historyStore.clearActiveGeneration('image');
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _handleCompletedResult(
    MediaGenerationResult result, {
    required String prompt,
    required DateTime createdAt,
  }) async {
    var items = result.toGeneratedItems(
      prompt: prompt,
      modelName: _selectedModel.name,
      createdAt: createdAt,
    );
    items = await MediaFileService.cacheItemsLocally(items);
    items = items.map((item) => item.copyWith(
      prompt: prompt,
      metadata: {...item.metadata, 'displayPrompt': prompt, 'originalPrompt': prompt},
    )).toList(growable: false);

    await _historyStore.prependItems(items);
    await _historyStore.clearActiveGeneration('image');

    if (!mounted) return;
    setState(() {
      _results.insertAll(0, items);
      _isGenerating = false;
    });
    _showSnack('Image generated successfully');
  }


  Future<void> _openInputPickerMenu() async {
    if (_isGenerating) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take photo'), onTap: () => Navigator.pop(context, 'camera')),
              ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Gallery'), onTap: () => Navigator.pop(context, 'gallery')),
              ListTile(leading: const Icon(Icons.insert_drive_file_outlined), title: const Text('File'), onTap: () => Navigator.pop(context, 'file')),
            ],
          ),
        ),
      ),
    );

    switch (action) {
      case 'camera':
        await _pickInputImage(_mediaInputHelper.pickFromCamera);
        break;
      case 'gallery':
        await _pickInputImage(_mediaInputHelper.pickFromGallery);
        break;
      case 'file':
        await _pickInputImage(_mediaInputHelper.pickFromFile);
        break;
    }
  }

  Future<void> _pickInputImage(Future<PickedInputImage?> Function() picker) async {
    if (_isGenerating) return;
    try {
      final picked = await picker();
      if (picked == null || !mounted) return;
      setState(() => _selectedInputImage = picked);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _removeSelectedImage() {
    setState(() => _selectedInputImage = null);
  }


  Future<void> _loadSavedHistory() async {
    try {
      final items = await _historyStore.loadByCategoryAndModel(
        'image',
        _selectedModel.id,
      );
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(items);
      });
    } catch (_) {}
  }

  Future<void> _deleteHistoryItem(GeneratedMediaItem item) async {
    setState(() {
      _results.removeWhere((e) =>
          e.previewUrl == item.previewUrl &&
          e.modelId == item.modelId &&
          e.createdAt == item.createdAt);
    });

    try {
      await _historyStore.deleteItem(item);
    } catch (_) {}
  }

  Future<void> _openHistorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: .92,
        child: ModelHistorySheet(
          category: 'image',
          modelId: _selectedModel.id,
          title: '${_selectedModel.name} history',
        ),
      ),
    );

    if (!mounted) return;
    await _loadSavedHistory();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String get _promptHint {
    if (_selectedInputImage != null) {
      return 'Describe how to transform or use the selected image...';
    }
    if (_supportsImageInput) {
      return 'Describe the image you want, or add an image and describe the edit...';
    }
    return 'Describe the image you want...';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Image Generator',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: scheme.surfaceVariant.withOpacity(.24),
                border: Border.all(color: scheme.outline.withOpacity(.10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create images',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a model, add an image when supported, then describe the final look you want.',
                    style: TextStyle(
                      height: 1.4,
                      color: scheme.onSurface.withOpacity(.68),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AbsorbPointer(
                    absorbing: _isGenerating,
                    child: _SelectedModelCard(model: _selectedModel, onTap: _pickModel),
                  ),
                  if (_supportsImageInput) ...[
                    const SizedBox(height: 14),
                    _InputPickerButton(
                      enabled: !_isGenerating,
                      hasImage: _selectedInputImage != null,
                      onTap: _openInputPickerMenu,
                    ),
                    const SizedBox(height: 12),
                    _SelectedInputPreview(
                      image: _selectedInputImage,
                      label: _selectedInputImage == null
                          ? 'Add a reference image when you want edits or guided generation.'
                          : 'Selected image ready for generation',
                      onRemove: _isGenerating || _selectedInputImage == null ? null : _removeSelectedImage,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _promptController,
                    enabled: !_isGenerating,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: _promptHint,
                      filled: true,
                      fillColor: isLight ? Colors.white : scheme.surface.withOpacity(.50),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  if (_isGenerating) ...[
                    const SizedBox(height: 14),
                    _RestoreInfoCard(label: 'Image generation is still running. You can leave and come back.'),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isGenerating ? null : _generate,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(_isGenerating ? 'Generating...' : 'Generate Image'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isGenerating ? null : _openHistorySheet,
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('History'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Results',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (_results.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: scheme.surfaceVariant.withOpacity(.20),
                  border: Border.all(color: scheme.outline.withOpacity(.08)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 42,
                      color: scheme.onSurface.withOpacity(.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No images yet',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _results
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: MediaResultCard(
                          key: ValueKey('${item.predictionId ?? item.previewUrl}-${item.createdAt.microsecondsSinceEpoch}'),
                          item: item,
                          onRegenerate: () {
                            _promptController.text = item.prompt;
                            _generate();
                          },
                          onDelete: () => _deleteHistoryItem(item),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}


class _RestoreInfoCard extends StatelessWidget {
  final String label;
  const _RestoreInfoCard({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.primary.withOpacity(.08),
        border: Border.all(color: scheme.primary.withOpacity(.16)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _SelectedModelCard extends StatelessWidget {
  final MediaModel model;
  final VoidCallback onTap;

  const _SelectedModelCard({
    required this.model,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.primary.withOpacity(.08),
          border: Border.all(color: scheme.primary.withOpacity(.16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: scheme.primary.withOpacity(.12),
              ),
              child: Icon(Icons.image_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to change model',
                    style: TextStyle(color: scheme.onSurface.withOpacity(.64)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputPickerButton extends StatelessWidget {
  final bool enabled;
  final bool hasImage;
  final VoidCallback onTap;

  const _InputPickerButton({
    required this.enabled,
    required this.hasImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: scheme.surfaceVariant.withOpacity(.22),
          border: Border.all(color: scheme.outline.withOpacity(.10)),
        ),
        child: Row(
          children: [
            Icon(hasImage ? Icons.image_rounded : Icons.add_photo_alternate_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasImage ? 'Change selected image' : 'Add image',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'Camera · Gallery · File',
              style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(.60)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleMediaModelSheet extends StatefulWidget {
  final List<MediaModel> models;
  final MediaModel selected;
  final String title;
  final String subtitle;

  const _SimpleMediaModelSheet({
    required this.models,
    required this.selected,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_SimpleMediaModelSheet> createState() => _SimpleMediaModelSheetState();
}

class _SimpleMediaModelSheetState extends State<_SimpleMediaModelSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      setState(() {
        _query = _search.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final models = widget.models.where((m) {
      if (_query.isEmpty) return true;
      final text = '${m.name} ${m.id} ${m.providerBadge} ${m.capabilityBadges.join(' ')} ${m.badge ?? ''}'.toLowerCase();
      return text.contains(_query);
    }).toList();

    final featured = models.where((m) => m.featured).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: TextStyle(color: scheme.onSurface.withOpacity(.68)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search models...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: scheme.surfaceVariant.withOpacity(.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              children: [
                if (featured.isNotEmpty) ...[
                  const Text(
                    'Featured',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  ...featured.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SheetModelTile(
                        model: m,
                        selected: m.id == widget.selected.id,
                        onTap: () => Navigator.pop(context, m),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'All Models',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...models.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SheetModelTile(
                      model: m,
                      selected: m.id == widget.selected.id,
                      onTap: () => Navigator.pop(context, m),
                    ),
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

class _SheetModelTile extends StatelessWidget {
  final MediaModel model;
  final bool selected;
  final VoidCallback onTap;

  const _SheetModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? scheme.primary.withOpacity(.08) : scheme.surfaceVariant.withOpacity(.20),
          border: Border.all(
            color: selected ? scheme.primary.withOpacity(.30) : scheme.outline.withOpacity(.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: scheme.primary.withOpacity(.10),
              ),
              child: Icon(Icons.image_rounded, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface.withOpacity(.62),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to change model',
                    style: TextStyle(color: scheme.onSurface.withOpacity(.64)),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _SelectedInputPreview extends StatelessWidget {
  final PickedInputImage? image;
  final String? label;
  final VoidCallback? onRemove;

  const _SelectedInputPreview({
    required this.image,
    this.label,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceVariant.withOpacity(.18),
        border: Border.all(color: scheme.outline.withOpacity(.10)),
      ),
      child: image == null
          ? Row(
              children: [
                Icon(Icons.image_outlined, color: scheme.onSurface.withOpacity(.65)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label ?? 'No image selected',
                    style: TextStyle(color: scheme.onSurface.withOpacity(.72)),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(image!.previewPath!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: scheme.surfaceVariant,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label ?? 'Selected image ready',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        image!.previewPath ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(.68),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove image',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
    );
  }
}