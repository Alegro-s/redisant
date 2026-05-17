import 'package:flutter/material.dart';

import '../../core/constants.dart';

class EntrySplashScreen extends StatefulWidget {
  const EntrySplashScreen({super.key, required this.child});

  final Widget child;

  @override
  State<EntrySplashScreen> createState() => _EntrySplashScreenState();
}

class _EntrySplashScreenState extends State<EntrySplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _splashOpacity;
  late final Animation<double> _splashScale;
  late final Animation<double> _contentOpacity;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
    _splashOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
    ).drive(Tween<double>(begin: 1.0, end: 0.0));
    _splashScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOutCubic),
    ).drive(Tween<double>(begin: 1.0, end: 0.92));
    _contentOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 1.0, curve: Curves.easeInOutCubic),
    ).drive(Tween<double>(begin: 0.0, end: 1.0));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await precacheImage(const AssetImage('assets/images/app_icon.png'), context);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 720));
      if (!mounted) return;
      await _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      body: Stack(
        fit: StackFit.expand,
        children: [
          FadeTransition(
            opacity: _contentOpacity,
            child: widget.child,
          ),
          if (!_done)
            FadeTransition(
              opacity: _splashOpacity,
              child: Container(
                color: AppConstants.surfaceWhite,
                child: Center(
                  child: ScaleTransition(
                    scale: _splashScale,
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.school_rounded,
                        size: 120,
                        color: AppConstants.blockBlack.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
