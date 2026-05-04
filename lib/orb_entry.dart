import 'package:flutter/material.dart';
import 'overlay_content.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayContent(), // 👈 Your orb widget
    ),
  );
}
