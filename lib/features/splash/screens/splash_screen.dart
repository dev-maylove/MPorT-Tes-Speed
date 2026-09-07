import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../speed_test/screens/main_screen.dart';

/// MPorT Go splash screen — plays logo animation video, then navigates to MainScreen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _navigated = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        // nav color set by MaterialApp theme

        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(
        'assets/videos/mport_splash.mp4',
      );
      _controller = controller;

      await controller.initialize();
      if (!mounted) return;

      // Play the splash video once and cover the entire Android screen.
      await controller.setLooping(false);
      await controller.setVolume(0); // mute audio

      controller.addListener(_onVideoUpdate);

      setState(() => _initialized = true);
      await controller.play();

      // Fallback: if video completion is not reported by the platform.
      Timer(
        controller.value.duration + const Duration(milliseconds: 500),
        _goToHome,
      );
    } catch (e) {
      // If video fails to load, continue to home immediately
      if (mounted) {
        setState(() => _hasError = true);
        Timer(const Duration(milliseconds: 800), _goToHome);
      }
    }
  }

  void _onVideoUpdate() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    final pos = c.value.position;
    final dur = c.value.duration;

    // Navigate when video is almost finished
    if (dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 80) {
      _goToHome();
    }
  }

  void _goToHome() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen video. BoxFit.cover fills the entire display while
          // preserving the video's aspect ratio.
          if (_initialized && _controller != null && !_hasError)
            LayoutBuilder(
              builder: (context, constraints) {
                final size = _controller!.value.size;
                return ClipRect(
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                );
              },
            )
          else if (!_hasError)
            // Loading sementara video initialize
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF00D4FF),
                  ),
                ),
              ),
            )
          else
            // Fallback on error: brief static logo
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/mport_logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'MPorT Go',
                    style: TextStyle(
                      color: Color(0xFF5CFFC9),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
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
