import 'package:flutter/material.dart';

import '../../core/constants.dart';

class EntrySplashScreen extends StatefulWidget {
  const EntrySplashScreen({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<EntrySplashScreen> createState() => _EntrySplashScreenState();
}

class _EntrySplashScreenState extends State<EntrySplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _lift;
  late final Animation<double> _logoScale;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) {
      _done = true;
      return;
    }
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1650));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _done = true);
    });
    _lift = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.16), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.16, end: 0.42), weight: 65),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await precacheImage(const AssetImage('assets/images/app_icon.png'), context);
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      await _controller.forward();
    });
  }

  @override
  void dispose() {
    if (widget.enabled) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _done) return widget.child;

    final liftPx = MediaQuery.sizeOf(context).height * 0.34;
    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(0, -liftPx * _lift.value),
                child: Container(
                  color: AppConstants.surfaceWhite,
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.school_rounded,
                        size: 120,
                        color: AppConstants.blockBlack.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
