import 'dart:io';
import 'package:flutter/material.dart';

bool _isRemote(String raw) => raw.startsWith('http://') || raw.startsWith('https://');

class MediaFullscreenViewer extends StatelessWidget {
  final String url;
  final String heroTag;

  const MediaFullscreenViewer({
    super.key,
    required this.url,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: _isRemote(url)
                ? Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'Unable to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                : Image.file(
                    File(url),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'Unable to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}