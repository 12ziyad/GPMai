// lib/spaces/ocr_page.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../services/sql_chat_store.dart';
import '../screens/chat_page.dart';

const _electricBlue = Color(0xFF00B8FF);
const _ocrOrange = Color(0xFFF57C00); // accent for OCR

// Strong OCR chat system prompt
const String _kOcrSystemPrompt = r'''
You are an OCR conversation assistant.
Context: The user will paste text extracted from an image (OCR) and may attach images.

Rules:
- Be concise by default (BRIEF MODE). If asked, expand.
- Preserve meaning, fix obvious OCR errors (broken words, wrong punctuation) conservatively.
- Keep structure where useful: paragraphs, lists, tables; do not invent content.
- If the user asks “what’s in this image/text?”, summarize key points.
- If the user asks to extract data (invoice/receipt/form), output a clean JSON with fields and values you can read; omit unknowns.
- If code is present, use fenced code blocks with the correct language.
- If math is present, render expressions with LaTeX where helpful.
- If the text is in another language, detect it; translate only when requested.
- If parts look low-confidence (garbled), say so briefly and suggest re-cropping or a sharper photo.
- Ask at most one short clarifying question if the goal is ambiguous.
[mood: neutral]
''';

class OcrPage extends StatefulWidget {
  final String userId;
  const OcrPage({super.key, required this.userId});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textCtrl = TextEditingController();

  File? _imageFile;
  File? _croppedFile;
  Uint8List? _thumbBytes;
  bool _isProcessing = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (!await Permission.camera.request().isGranted) {
      _toast('Camera permission denied.');
      return;
    }
    final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (shot == null) return;
    _setImage(File(shot.path));
    await _cropAndOcr();
  }

  Future<void> _pickFromGallery() async {
    final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (img == null) return;
    _setImage(File(img.path));
    await _cropAndOcr();
  }

  void _setImage(File f) async {
    _imageFile = f;
    try {
      _thumbBytes = await f.readAsBytes();
    } catch (_) {
      _thumbBytes = null;
    }
    setState(() {});
  }

  Future<void> _cropAndOcr() async {
    if (_imageFile == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: _imageFile!.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop & Continue',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: _electricBlue,
          hideBottomControls: false,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop & Continue',
          aspectRatioLockEnabled: false,
        ),
      ],
    );
    if (cropped == null) return;

    _croppedFile = File(cropped.path);
    try {
      _thumbBytes = await _croppedFile!.readAsBytes();
    } catch (_) {
      _thumbBytes = null;
    }
    setState(() {});
    await _runOcr();
  }

  Future<void> _runOcr() async {
    final file = _croppedFile ?? _imageFile;
    if (file == null) return;

    setState(() => _isProcessing = true);
    try {
      final input = InputImage.fromFile(file);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(input);
      await recognizer.close();

      final text = result.text.trim();
      _textCtrl.text = text;
      _textCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _textCtrl.text.length),
      );
    } catch (e) {
      _toast('OCR failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _continueToChat() async {
    final txt = _textCtrl.text.trim();
    final store = SqlChatStore();

    // store preset so ChatPage can show an OCR avatar
    final chatId = await store.createChat(
      name: 'OCR',
      preset: {'kind': 'tool', 'id': 'ocr'},
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          userId: widget.userId,
          chatId: chatId,
          chatName: 'OCR',
          prefillInput: txt,                  // put text into the composer
          systemPrompt: _kOcrSystemPrompt,    // strong OCR system prompt
        ),
      ),
    );
  }

  void _clearImage() {
    _imageFile = null;
    _croppedFile = null;
    _thumbBytes = null;
    setState(() {});
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageFile != null || _croppedFile != null;
    final canContinue = _textCtrl.text.trim().isNotEmpty && !_isProcessing;

    return Scaffold(
      appBar: AppBar(title: const Text('OCR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _BigActionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take Photo',
                    onTap: _pickFromCamera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BigActionButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Choose Photo',
                    onTap: _pickFromGallery,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (hasImage)
              Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _thumbBytes != null
                          ? Image.memory(_thumbBytes!, fit: BoxFit.cover)
                          : const Icon(Icons.image, size: 36),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: InkWell(
                        onTap: _clearImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (hasImage) const SizedBox(height: 12),

            if (hasImage)
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.crop_rounded),
                    label: const Text('Crop Again'),
                    onPressed: _cropAndOcr,
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Replace'),
                    onPressed: () async {
                      _clearImage();
                      await _pickFromGallery();
                    },
                  ),
                ],
              ),

            const SizedBox(height: 16),

            TextField(
              controller: _textCtrl,
              maxLines: 10,
              minLines: 5,
              decoration: InputDecoration(
                labelText: 'OCR Text',
                alignLabelWithHint: true,
                hintText: 'Recognized text will appear here…',
                border: const OutlineInputBorder(),
                suffixIcon: _isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Clear text',
                        icon: const Icon(Icons.clear_all_rounded),
                        onPressed: () => _textCtrl.clear(),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy'),
                  onPressed: () async {
                    final txt = _textCtrl.text;
                    if (txt.trim().isEmpty) return;
                    await Clipboard.setData(ClipboardData(text: txt));
                    _toast('Copied');
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _electricBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  label: const Text('Continue to Chat'),
                  onPressed: canContinue ? _continueToChat : null,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Tip / explanation card
            _TipCard(),
          ],
        ),
      ),
    );
  }
}

/* visuals */

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = (cs.brightness == Brightness.dark ? _electricBlue : Colors.black87)
        .withOpacity(cs.brightness == Brightness.dark ? .35 : .18);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [_electricBlue.withOpacity(.25), const Color(0xFFFFB74D).withOpacity(.22)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _ocrOrange),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.tips_and_updates_rounded, color: _ocrOrange),
            const SizedBox(width: 8),
            const Text('How to use OCR', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          const Text('1) Tap “Take Photo” or “Choose Photo”.'),
          const Text('2) Crop to the text area and confirm.'),
          const Text('3) Edit the recognized text if needed → Continue to Chat.'),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.document_scanner_rounded, color: _ocrOrange),
            const SizedBox(width: 8),
            const Text('What is OCR?', style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(
            'OCR (Optical Character Recognition) converts text in images into editable text. '
            'Use a clear, well-lit photo for best results.',
            style: TextStyle(color: cs.onSurface.withOpacity(.85)),
          ),
        ]),
      ),
    );
  }
}
