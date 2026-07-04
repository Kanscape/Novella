import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';

const m3eCenterRevealTransitionDuration = Duration(milliseconds: 760);
const m3eCenterRevealReverseTransitionDuration = Duration(milliseconds: 260);
const _revealStart = 0.12;

Route<T> createM3ECenterRevealRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    opaque: true,
    transitionDuration: m3eCenterRevealTransitionDuration,
    reverseTransitionDuration: m3eCenterRevealReverseTransitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _M3ECenterRevealTransition(animation: animation, child: child),
  );
}

class M3ECenterRevealClipper extends CustomClipper<Path> {
  M3ECenterRevealClipper({required double progress})
    : _progress = progress,
      _progressAnimation = null,
      super();

  M3ECenterRevealClipper.animated({
    required Animation<double> progressAnimation,
  }) : _progress = null,
       _progressAnimation = progressAnimation,
       super(reclip: progressAnimation);

  final double? _progress;
  final Animation<double>? _progressAnimation;

  double get progress =>
      (_progressAnimation?.value ?? _progress ?? 0).clamp(0.0, 1.0);

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(math.pow(size.width / 2, 2) + math.pow(size.height / 2, 2)) +
        1;
    final radius = maxRadius * progress.clamp(0, 1);

    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(M3ECenterRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

class _M3ECenterRevealTransition extends StatefulWidget {
  const _M3ECenterRevealTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  State<_M3ECenterRevealTransition> createState() =>
      _M3ECenterRevealTransitionState();
}

class _M3ECenterRevealTransitionState
    extends State<_M3ECenterRevealTransition> {
  late Animation<double> _revealAnimation;
  late Animation<double> _loadingOpacityAnimation;
  late Animation<double> _loadingScaleAnimation;
  late Animation<double> _contentScaleAnimation;
  late bool _transitionComplete;

  @override
  void initState() {
    super.initState();
    _configureAnimations();
    _transitionComplete = widget.animation.isCompleted;
    widget.animation.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(_M3ECenterRevealTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation == widget.animation) {
      return;
    }

    oldWidget.animation.removeStatusListener(_handleAnimationStatus);
    _configureAnimations();
    _transitionComplete = widget.animation.isCompleted;
    widget.animation.addStatusListener(_handleAnimationStatus);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleAnimationStatus);
    super.dispose();
  }

  void _configureAnimations() {
    _revealAnimation = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(_revealStart, 1, curve: Curves.easeInOutCubic),
    );
    _loadingOpacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: widget.animation,
        curve: const Interval(_revealStart, 0.42, curve: Curves.easeOut),
      ),
    );
    _loadingScaleAnimation = Tween<double>(begin: 1, end: 0.92).animate(
      CurvedAnimation(
        parent: widget.animation,
        curve: const Interval(_revealStart, 0.42, curve: Curves.easeOut),
      ),
    );
    _contentScaleAnimation = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(_revealAnimation);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    final complete = status == AnimationStatus.completed;
    if (_transitionComplete == complete) {
      return;
    }

    setState(() => _transitionComplete = complete);
  }

  @override
  Widget build(BuildContext context) {
    if (_transitionComplete) {
      return widget.child;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: colorScheme.surface,
          child: FadeTransition(
            opacity: _loadingOpacityAnimation,
            child: ScaleTransition(
              scale: _loadingScaleAnimation,
              child: const Center(child: M3ELoadingIndicator()),
            ),
          ),
        ),
        ClipPath(
          clipper: M3ECenterRevealClipper.animated(
            progressAnimation: _revealAnimation,
          ),
          child: ScaleTransition(
            scale: _contentScaleAnimation,
            child: RepaintBoundary(child: widget.child),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _M3ECenterRevealHaloPainter(
              progressAnimation: _revealAnimation,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _M3ECenterRevealHaloPainter extends CustomPainter {
  _M3ECenterRevealHaloPainter({
    required this.progressAnimation,
    required this.color,
  }) : super(repaint: progressAnimation);

  final Animation<double> progressAnimation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = progressAnimation.value.clamp(0.0, 1.0);
    if (progress <= 0 || progress >= 1) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius =
        math.sqrt(math.pow(size.width / 2, 2) + math.pow(size.height / 2, 2)) +
        1;
    final radius = maxRadius * progress;
    final opacity = (1 - progress).clamp(0.0, 1.0);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20 - progress * 10
      ..color = color.withValues(alpha: 0.18 * opacity);
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color.withValues(alpha: 0.36 * opacity);

    canvas.drawCircle(center, radius, glowPaint);
    canvas.drawCircle(center, radius, edgePaint);
  }

  @override
  bool shouldRepaint(_M3ECenterRevealHaloPainter oldDelegate) {
    return oldDelegate.progressAnimation != progressAnimation ||
        oldDelegate.color != color;
  }
}
