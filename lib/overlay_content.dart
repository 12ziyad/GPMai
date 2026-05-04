import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../groq/model_router.dart';

class OverlayContent extends StatefulWidget {
  const OverlayContent({super.key});
  @override
  State<OverlayContent> createState() => OverlayContentState();
}

class OverlayContentState extends State<OverlayContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _position = const Offset(100, 100); // Start somewhere visible
  double _spinZ = 0.0;
  final Random _random = Random();
  String _currentMood = "neutral";

  bool _isTapped = false;
  bool _isDragging = false;
  bool _showChatBubble = false;

  String _userText = '';
  String _responseText = '';
  final TextEditingController _textController = TextEditingController();

  static Function(String mood)? globalMoodController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _startSpinTimer();
    globalMoodController = _setMood;
  }

  void _startSpinTimer() {
    Timer.periodic(const Duration(seconds: 6), (_) {
      setState(() {
        double dir = _random.nextBool() ? 1 : -1;
        _spinZ += dir * (2 * pi * (_random.nextInt(2) + 2));
      });
    });
  }

  void _setMood(String mood) {
    setState(() => _currentMood = mood);
  }

  void _triggerPulse() {
    setState(() => _isTapped = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isTapped = false);
    });
  }

  void _handleTap() => _triggerPulse();
  void _toggleChatBubble() =>
      setState(() => _showChatBubble = !_showChatBubble);

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _userText = text;
      _responseText = 'Thinking...';
    });

    final raw = await ModelRouter.getResponse(text);
    final response = utf8.decode(raw.runes.toList());

    setState(() {
      _responseText = response;
      _textController.clear();
    });
  }

  String _orbImageForMood(String mood) {
    switch (mood) {
      case "love":
        return 'assets/orb_love.png';
      case "fire":
        return 'assets/orb_fire.png';
      case "cold":
        return 'assets/orb_cold.png';
      case "sleep":
        return 'assets/orb_sleep.png';
      case "dead":
        return 'assets/orb_dead.png';
      case "happy":
        return 'assets/orb_gold.png';
      default:
        return 'assets/ai_orb.png';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orbImage = _orbImageForMood(_currentMood);
    final scale =
        (_isTapped || _isDragging)
            ? 1.25
            : 1.0 + 0.12 * sin(_controller.value * 2 * pi);
    final isLeft = _position.dx < MediaQuery.of(context).size.width / 2;

    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: GestureDetector(
              onTap: _handleTap,
              onDoubleTap: _toggleChatBubble,
              onPanStart: (_) => setState(() => _isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  _position += details.delta;
                });
              },
              onPanEnd: (_) => setState(() => _isDragging = false),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  final floatY = 10 * sin(_controller.value * 2 * pi);
                  return Transform.translate(
                    offset: Offset(0, floatY),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateZ(_spinZ),
                      child: Transform.scale(
                        scale: scale,
                        child: Image.asset(orbImage, width: 80, height: 80),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Chat Bubble
          if (_showChatBubble)
            Positioned(
              left: isLeft ? _position.dx + 90 : null,
              right: isLeft ? null : 10,
              top: _position.dy - 40,
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_userText.isNotEmpty)
                      Text(
                        "You: $_userText",
                        style: const TextStyle(color: Colors.blueAccent),
                      ),
                    if (_responseText.isNotEmpty)
                      Text(
                        "GPMai: $_responseText",
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Message GPMai...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
