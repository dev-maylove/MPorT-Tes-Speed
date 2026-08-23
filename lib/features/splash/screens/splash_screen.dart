import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../speed_test/screens/main_screen.dart';

/// Splash screen MPorT Go — logo + animasi masuk, lalu navigasi ke MainScreen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<double> _progressOpacity;
  late final Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.72, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
    ]).animate(_controller);

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.65, curve: Curves.easeOut),
      ),
    );

    _progressOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.70, curve: Curves.easeOut),
      ),
    );

    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.95, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();

    // Navigasi setelah animasi selesai
    Timer(const Duration(milliseconds: 2400), _goToHome);
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionDuration: const Duration(milliseconds: 450),
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = (size.shortestSide * 0.28).clamp(96.0, 140.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Soft radial glow di belakang logo
              Center(
                child: Opacity(
                  opacity: _logoOpacity.value * 0.35,
                  child: Container(
                    width: logoSize * 2.2,
                    height: logoSize * 2.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.green.withValues(alpha: 0.22),
                          AppColors.green.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // Konten utama
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),

                    // Logo
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(logoSize * 0.22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.green
                                    .withValues(alpha: 0.35 * _logoOpacity.value),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(logoSize * 0.22),
                            child: Image.asset(
                              'assets/images/mport_logo.png',
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Nama aplikasi
                    Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        children: [
                          Text(
                            AppConstants.appName,
                            style: TextStyle(
                              color: AppColors.greenLight,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: AppColors.green
                                      .withValues(alpha: 0.45),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tes Kecepatan Internet',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Progress bar tipis
                    Opacity(
                      opacity: _progressOpacity.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 72),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progressValue.value,
                                minHeight: 3.5,
                                backgroundColor:
                                    AppColors.surface.withValues(alpha: 0.8),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.green.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Memuat...',
                              style: TextStyle(
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Versi
                    Opacity(
                      opacity: _textOpacity.value * 0.7,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          'v${AppConstants.appVersion}',
                          style: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
