import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerPage extends StatefulWidget {
  final String title;
  final String? filePath;   // prefer this if available
  final Uint8List? bytes;   // fallback in-memory bytes

  const PdfViewerPage({
    super.key,
    required this.title,
    this.filePath,
    this.bytes,
  });

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  late final PdfViewerController _controller = PdfViewerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget viewer;
    if (widget.filePath != null && File(widget.filePath!).existsSync()) {
      viewer = SfPdfViewer.file(
        File(widget.filePath!),
        controller: _controller,
        onDocumentLoadFailed: (d) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load: ${d.description}')),
          );
        },
      );
    } else if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      viewer = SfPdfViewer.memory(
        widget.bytes!,
        controller: _controller,
        onDocumentLoadFailed: (d) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load: ${d.description}')),
          );
        },
      );
    } else {
      viewer = const Center(child: Text('Unable to load PDF'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _controller.zoomLevel = _controller.zoomLevel + 0.25,
          ),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
            onPressed: () =>
                _controller.zoomLevel = (_controller.zoomLevel - 0.25).clamp(1.0, 6.0),
          ),
        ],
      ),
      body: viewer,
    );
  }
}
