import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ✅ Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/home_shell.dart' as shell;
import 'app_theme.dart';
import 'services/sql_chat_store.dart';
import 'brain_channel.dart' show BrainChannel;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Touch DB singleton (lazy create later)
  // ignore: unnecessary_statements
  AppDatabase.I;

  // ✅ Init BrainChannel
  try {
    BrainChannel.init();
    debugPrint('🧠[main] BrainChannel.init() done');
  } catch (e) {
    debugPrint('🧠[main] BrainChannel.init() failed: $e');
  }

  // ✅ Init Firebase BEFORE runApp
  String uid = "anon_pending";

  try {
    debugPrint('🔐[auth] Firebase init start...');
    await Firebase.initializeApp();
    debugPrint('🔐[auth] Firebase init done');

    final auth = FirebaseAuth.instance;

    if (auth.currentUser == null) {
      final cred = await auth.signInAnonymously();
      uid = cred.user?.uid ?? "anon_pending";
      debugPrint('✅[auth] Signed in anonymously uid=$uid');
    } else {
      uid = auth.currentUser!.uid;
      debugPrint('✅[auth] Existing user uid=$uid');
    }

    // ✅ FORCE fresh Firebase ID token and print it cleanly
    try {
      final token = await auth.currentUser?.getIdToken(true);

      debugPrint('🪪 UID=$uid');
      debugPrint('TOKEN_START');
      if (token != null && token.isNotEmpty) {
        debugPrint(token);
      } else {
        debugPrint('null');
      }
      debugPrint('TOKEN_END');
    } catch (e) {
      debugPrint('🔴[auth] getIdToken failed: $e');
    }
  } catch (e) {
    debugPrint('🔴[auth] init/signin failed: $e');
  }

  // ✅ Launch app with safe uid
  runApp(GPMaiApp(uid: uid));

  // ✅ After UI loads, only sync /me (NO debug /chat ping)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      debugPrint('👤[/me] syncing wallet...');
      // if needed later, call your wallet sync here
    } catch (e) {
      debugPrint('🔴[/me] error: $e');
    }
  });
}

class GPMaiApp extends StatefulWidget {
  final String uid;
  const GPMaiApp({super.key, required this.uid});

  @override
  State<GPMaiApp> createState() => _GPMaiAppState();
}

class _GPMaiAppState extends State<GPMaiApp> {
  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.dark);

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'GPMai',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          builder: (context, child) {
            return Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (c, a) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0.02),
                      end: Offset.zero,
                    ).animate(a),
                    child: FadeTransition(opacity: a, child: c),
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              ],
            );
          },
          home: shell.HomeShell(
            userId: widget.uid,
            onChangeTheme: (ThemeMode m) => _themeMode.value = m,
            currentThemeMode: _themeMode.value,
          ),
        );
      },
    );
  }
}

/* ------------------------------------------------------------------
   Everything below is your existing Orb overlay code
------------------------------------------------------------------ */

class _OrbSummonOverlay extends StatefulWidget {
  const _OrbSummonOverlay();

  @override
  State<_OrbSummonOverlay> createState() => _OrbSummonOverlayState();
}

enum _OrbState { idle, starting, running, stopping }

class _OrbSummonOverlayState extends State<_OrbSummonOverlay>
    with TickerProviderStateMixin {
  static const MethodChannel _orb = MethodChannel('gpmai/orb_channel');

  late final AnimationController _ringCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();

  late final AnimationController _puffCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _puff = Tween(begin: 1.00, end: 1.12)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_puffCtrl);

  late final AnimationController _turnCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 21))
        ..repeat();

  late final Animation<double> _turn = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: -math.pi / 2)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: -math.pi / 2, end: 0.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 2 * math.pi)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 1,
    ),
  ]).animate(_turnCtrl);

  _OrbState _state = _OrbState.idle;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _isBusy =>
      _state == _OrbState.starting || _state == _OrbState.stopping;

  bool _tapAllowed() {
    final now = DateTime.now();
    if (now.difference(_lastTap).inMilliseconds < 220) return false;
    _lastTap = now;
    return true;
  }

  Future<void> _startOrb() async {
    if (_isBusy || _state == _OrbState.running) return;
    setState(() => _state = _OrbState.starting);
    debugPrint('🟢[orb] start requested');
    try {
      final result =
          await _orb.invokeMethod('startOrb').timeout(const Duration(seconds: 5));
      debugPrint('🟢[orb] startOrb ok → $result');
      if (!mounted) return;
      setState(() => _state = _OrbState.running);
    } on TimeoutException {
      debugPrint('🟠[orb] startOrb timed out');
      if (!mounted) return;
      setState(() => _state = _OrbState.idle);
    } catch (e) {
      debugPrint('🔴[orb] startOrb error: $e');
      if (!mounted) return;
      setState(() => _state = _OrbState.idle);
    }
  }

  Future<void> _stopOrb() async {
    if (_isBusy || _state == _OrbState.idle) return;
    setState(() => _state = _OrbState.stopping);
    debugPrint('🛑[orb] stop requested (long-press)');
    try {
      final result =
          await _orb.invokeMethod('stopOrb').timeout(const Duration(seconds: 5));
      debugPrint('🛑[orb] stopOrb ok → $result');
      if (!mounted) return;
      setState(() => _state = _OrbState.idle);
    } on TimeoutException {
      debugPrint('🟠[orb] stopOrb timed out');
      if (!mounted) return;
      setState(() => _state = _OrbState.idle);
    } catch (e) {
      debugPrint('🔴[orb] stopOrb error: $e');
      if (!mounted) return;
      setState(() => _state = _OrbState.idle);
    }
  }

  void _onTap() {
    if (!_tapAllowed() || _isBusy) return;
    debugPrint('👆[orb] tap');
    _startOrb();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _puffCtrl.dispose();
    _turnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 8;
    const right = 12.0;

    const outerSize = 56.0;
    const ringWidth = 3.5;
    const innerDisc = outerSize - 4 * ringWidth - 2;
    const imgSize = innerDisc;

    final showInner = _state != _OrbState.running;

    return Positioned(
      top: top,
      right: right,
      child: _AnimatedOrbButton(
        size: outerSize,
        ringWidth: ringWidth,
        imgSize: imgSize,
        ringProgress: _ringCtrl,
        puff: _puff,
        rotation: _turn,
        showInnerOrb: showInner,
        onTap: _onTap,
        onLongPress: _stopOrb,
        disabled: _isBusy,
      ),
    );
  }
}

class _AnimatedOrbButton extends StatelessWidget {
  final double size;
  final double ringWidth;
  final double imgSize;
  final Animation<double> ringProgress;
  final Animation<double> puff;
  final Animation<double> rotation;
  final bool showInnerOrb;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool disabled;

  const _AnimatedOrbButton({
    required this.size,
    required this.ringWidth,
    required this.imgSize,
    required this.ringProgress,
    required this.puff,
    required this.rotation,
    required this.showInnerOrb,
    required this.onTap,
    required this.onLongPress,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ringProgress, puff, rotation]),
      builder: (_, __) {
        return Opacity(
          opacity: disabled ? 0.85 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : onTap,
              onLongPress: disabled ? null : onLongPress,
              customBorder: const CircleBorder(),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D0F12), Color(0xFF151920)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.all(ringWidth),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      startAngle: 0,
                      endAngle: 2 * math.pi,
                      transform:
                          GradientRotation(ringProgress.value * 2 * math.pi),
                      colors: const [
                        Color(0xFF00E5FF),
                        Color(0xFF3DDCFF),
                        Color(0xFF00B8FF),
                        Color(0xFF6CF7FF),
                        Color(0xFFEFFFFF),
                        Color(0xFF00B8FF),
                        Color(0xFF008CFF),
                        Color(0xFF00E5FF),
                      ],
                      stops: [
                        0.00,
                        0.12,
                        0.26,
                        0.42,
                        0.58,
                        0.76,
                        0.88,
                        1.00
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(ringWidth + 1),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          opacity: showInnerOrb ? 1 : 0,
                          child: Transform.rotate(
                            angle: rotation.value,
                            child: Transform.scale(
                              scale: puff.value,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/ai_orb.png',
                                  width: imgSize,
                                  height: imgSize,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}