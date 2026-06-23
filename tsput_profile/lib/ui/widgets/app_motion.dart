import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration introDuration = Duration(milliseconds: 900);
  static const Duration panelDuration = Duration(milliseconds: 440);
  static const Duration chipDuration = Duration(milliseconds: 280);
  static const Duration staggerStep = Duration(milliseconds: 60);
  static const double revealOffset = 12;
  static const Curve curve = Curves.easeOutCubic;
  static const Curve panelCurve = Curves.easeInOutCubic;
}

class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.animation,
    required this.child,
    this.offset = AppMotion.revealOffset,
  });

  final Animation<double> animation;
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t.clamp(0.001, 1.0),
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, -offset * (1 - t)),
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class AppIntroColumn extends StatefulWidget {
  const AppIntroColumn({
    super.key,
    required this.children,
    this.spacing = 0,
    this.runIntro = true,
  });

  final List<Widget> children;
  final double spacing;
  final bool runIntro;

  @override
  State<AppIntroColumn> createState() => _AppIntroColumnState();
}

class _AppIntroColumnState extends State<AppIntroColumn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.introDuration);
    if (widget.runIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _itemCurve(int index, int total) {
    final start = (index / total) * 0.52;
    final end = (start + 0.48).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: AppMotion.curve),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.children.length;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0 && widget.spacing > 0) SizedBox(height: widget.spacing),
          AppReveal(
            animation: _itemCurve(i, total),
            child: widget.children[i],
          ),
        ],
      ],
    );
  }
}

class AppPanelSwitcher extends StatelessWidget {
  const AppPanelSwitcher({
    super.key,
    required this.itemKey,
    required this.child,
    this.duration = AppMotion.panelDuration,
    this.alignment = Alignment.topCenter,
  });

  final Object itemKey;
  final Widget child;
  final Duration duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.panelCurve,
      switchOutCurve: AppMotion.panelCurve,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        clipBehavior: Clip.none,
        children: [
          ...previous,
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.panelCurve);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(itemKey),
        child: child,
      ),
    );
  }
}

class AppTabEnter extends StatefulWidget {
  const AppTabEnter({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<AppTabEnter> createState() => _AppTabEnterState();
}

class _AppTabEnterState extends State<AppTabEnter> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.panelDuration);
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.panelCurve);
    _slide = Tween<Offset>(begin: const Offset(0, 0.018), end: Offset.zero).animate(_fade);
    if (widget.active) _controller.value = 1;
  }

  @override
  void didUpdateWidget(AppTabEnter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class AppRevealList extends StatefulWidget {
  const AppRevealList({
    super.key,
    required this.listKey,
    required this.children,
    this.spacing = 10,
  });

  final Object listKey;
  final List<Widget> children;
  final double spacing;

  @override
  State<AppRevealList> createState() => _AppRevealListState();
}

class _AppRevealListState extends State<AppRevealList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.introDuration);
    _run();
  }

  @override
  void didUpdateWidget(AppRevealList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listKey != widget.listKey) _run();
  }

  void _run() {
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _itemCurve(int index, int total) {
    final start = (index / total) * 0.45;
    final end = (start + 0.55).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: AppMotion.curve),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.children.length;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) SizedBox(height: widget.spacing),
          AppReveal(
            animation: _itemCurve(i, total),
            child: widget.children[i],
          ),
        ],
      ],
    );
  }
}
