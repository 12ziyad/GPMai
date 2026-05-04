// lib/spaces/upload_ask_page.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/image_qa_recents_store.dart';
import 'image_answer_page.dart';

class UploadAskPage extends StatefulWidget {
  const UploadAskPage({super.key, this.userId});
  final String? userId;

  @override
  State<UploadAskPage> createState() => _UploadAskPageState();
}

class _UploadAskPageState extends State<UploadAskPage> {
  final ImagePicker _picker = ImagePicker();

  List<ImageQARecentItem> _recents = <ImageQARecentItem>[];
  final Set<String> _selected = <String>{};
  bool get _selectionMode => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final items = await ImageQARecentsStore.list();
    if (!mounted) return;
    setState(() {
      _recents = items;
      _selected.removeWhere((id) => !_recents.any((e) => e.id == id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Image Q&A')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Upload card
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Upload a photo', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickFromCamera,
                          icon: const Icon(Icons.photo_camera_rounded),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurface.withOpacity(.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Pick or crop an image. We’ll open Q&A with it ready.',
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(.7)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ideas
          Text('Ideas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _IdeaChips(onTap: _startIdeaFlow),

          const SizedBox(height: 18),

          // ── Recents header: Select all → then only Delete ──
          Row(
            children: [
              Text('Recents', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (_selectionMode) ...[
                IconButton(
                  tooltip: 'Delete selected',
                  icon: const Icon(Icons.delete_forever_rounded),
                  onPressed: _deleteSelected,
                ),
              ] else ...[
                IconButton(
                  tooltip: 'Select all',
                  icon: const Icon(Icons.done_all_rounded),
                  onPressed: () {
                    setState(() {
                      _selected
                        ..clear()
                        ..addAll(_recents.map((e) => e.id));
                    });
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          if (_recents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No recents yet.', style: TextStyle(color: cs.onSurface.withOpacity(.6))),
            )
          else
            ..._recents.map((r) {
              final selected = _selected.contains(r.id);
              return GestureDetector(
                onLongPress: () => _showRowMenu(r), // Pin / Unpin / Rename / Delete
                onTap: () => _selectionMode ? _toggleSelect(r.id) : _openAnswerPageFromDisk(r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).cardColor,
                    border: Border.all(
                      color: selected ? cs.primary : Colors.white12,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(r.imagePath),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (r.pinned) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.push_pin_rounded, size: 16),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.createdAt.toLocal().toString(),
                              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(.6)),
                            ),
                          ],
                        ),
                      ),
                      // quick row controls (kept)
                      IconButton(
                        tooltip: selected ? 'Unselect' : 'Select',
                        icon: Icon(selected ? Icons.check_circle : Icons.check_circle_outline),
                        onPressed: () => _toggleSelect(r.id),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _deleteOne(r),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  /* ------- picking / idea flow ------- */

  Future<void> _pickFromCamera() async {
    if (!await Permission.camera.request().isGranted) {
      _toast('Camera permission denied.');
      return;
    }
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (x == null) return;
    await _confirmCropOrContinue(x);
  }

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (x == null) return;
    await _confirmCropOrContinue(x);
  }

  Future<void> _startIdeaFlow(String ideaText) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (source == ImageSource.camera) {
      if (!await Permission.camera.request().isGranted) {
        _toast('Camera permission denied.');
        return;
      }
    }
    final x = await _picker.pickImage(source: source, imageQuality: 90);
    if (x == null) return;
    await _confirmCropOrContinue(x, ideaText: ideaText);
  }

  Future<void> _confirmCropOrContinue(XFile xfile, {String? ideaText}) async {
    if (!mounted) return;

    final preview = Image.file(File(xfile.path), fit: BoxFit.cover);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(height: 220, width: double.infinity, child: preview),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'continue'),
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    label: const Text('Continue'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, 'crop'),
                    icon: const Icon(Icons.crop_rounded),
                    label: const Text('Crop'),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    Uint8List bytes;
    if (action == 'crop') {
      final cropped = await ImageCropper().cropImage(
        sourcePath: xfile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: Theme.of(context).colorScheme.surface,
            toolbarWidgetColor: Theme.of(context).colorScheme.onSurface,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop'),
          WebUiSettings(context: context),
        ],
      );
      if (cropped == null) return;
      bytes = await cropped.readAsBytes();
    } else {
      bytes = await xfile.readAsBytes();
    }

    final item = await ImageQARecentsStore.add(bytes, prompt: ideaText);
    // When we open the saved item later from Recents, DO NOT auto-ask again.
    await _openAnswerPage(item.id, bytes, firstPrompt: ideaText);
    _loadRecents();
  }

  Future<void> _openAnswerPage(String itemId, Uint8List imageBytes, {String? firstPrompt}) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageAnswerPage(
          itemId: itemId,
          image: imageBytes,
          firstPrompt: firstPrompt,
          autoAskOnOpen: firstPrompt != null && firstPrompt.trim().isNotEmpty,
        ),
      ),
    );
  }

  Future<void> _openAnswerPageFromDisk(ImageQARecentItem r) async {
    final f = File(r.imagePath);
    if (!await f.exists()) return;
    final bytes = await f.readAsBytes();
    // 🔒 Stop auto-send when reopening: pass null so ImageAnswerPage won't auto ask
    await _openAnswerPage(r.id, bytes, firstPrompt: null);
  }

  /* ---------------- header & row actions ---------------- */

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  Future<void> _deleteOne(ImageQARecentItem r) async {
    await ImageQARecentsStore.removeMany([r.id]);
    _selected.remove(r.id);
    _loadRecents();
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    await ImageQARecentsStore.removeMany(_selected.toList());
    _selected.clear();
    _loadRecents();
  }

  Future<void> _showRowMenu(ImageQARecentItem r) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            if (!r.pinned)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Pin'),
                onTap: () => Navigator.pop(context, 'pin'),
              ),
            if (r.pinned)
              ListTile(
                leading: const Icon(Icons.push_pin_rounded),
                title: const Text('Unpin'),
                onTap: () => Navigator.pop(context, 'unpin'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;
    if (choice == 'rename') {
      final t = await _askRename(r.title);
      if (t != null) {
        await ImageQARecentsStore.rename(r.id, t);
        _loadRecents();
      }
    } else if (choice == 'pin') {
      await ImageQARecentsStore.togglePinMany([r.id], pinned: true);
      _loadRecents();
    } else if (choice == 'unpin') {
      await ImageQARecentsStore.togglePinMany([r.id], pinned: false);
      _loadRecents();
    } else if (choice == 'delete') {
      await _deleteOne(r);
    }
  }

  Future<String?> _askRename(String current) async {
    final c = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/* ------------------- chips ------------------- */

class _IdeaChips extends StatelessWidget {
  const _IdeaChips({required this.onTap});
  final void Function(String ideaText) onTap;

  @override
  Widget build(BuildContext context) {
    final ideas = <String>[
      'What is this?',
      'Explain this diagram.',
      'Extract the text.',
      'Translate the sign to English.',
      'Identify the landmark.',
      'Describe the outfit style.',
      'Summarise the poster.',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 4),
          for (final t in ideas) ...[
            ActionChip(
              avatar: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(t),
              onPressed: () => onTap(t),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}
