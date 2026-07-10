import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

// 尺寸常量（外层包装：把 48dp 规范指示器缩放到调用方给定尺寸）
const _packageContainerSize = 48.0;
const _packageActiveIndicatorSize = 38.0;
const _packageActiveIndicatorScale =
    _packageActiveIndicatorSize / _packageContainerSize;

// 指示器核心常量（源自 Material 3 Expressive loading indicator 规范）
const _kContainerSize = 48.0;
const _kActiveIndicatorSize = 38.0;
const _kActiveIndicatorScale = _kActiveIndicatorSize / _kContainerSize;
const _kFullRotationAngle = math.pi * 2;
const _kSingleRotationAngle = math.pi * 3 / 4;
const _kLinearRotationAngle = math.pi / 4;
const _kMorphRotationAngle = _kSingleRotationAngle - _kLinearRotationAngle;

// 默认形变形状序列。单例，供缓存按身份复用（全 App 共享）。
final _indeterminatePolygons = <RoundedPolygon>[
  MaterialShapes.softBurst,
  MaterialShapes.cookie9Sided,
  MaterialShapes.pentagon,
  MaterialShapes.pill,
  MaterialShapes.sunny,
  MaterialShapes.cookie4Sided,
  MaterialShapes.oval,
];

// ============================================================================
// 性能优化：形变几何跨实例共享缓存
//
// 同一套多边形在任意 progress 下的形变结果是确定的，与实例、尺寸无关（尺寸由
// canvas 变换事后施加）。原实现每个 spinner 各自：① 挂载时重算 Morph 匹配
// （LengthMeasurer/featureMapper）② 每帧重算 toPath（曲线插值 + Path 构建）。
// 同屏大量封面加载时开销 ∝ spinner 数。
//
// 优化：① Morph 匹配按多边形列表身份缓存一次；② toPath 结果按
// (morphSetId, morphIndex, 量化progress) 缓存，每帧退化成一次查表。
// 旋转/缩放仍逐帧连续，仅形状几何按 _kMorphPathSteps 步量化（肉眼无差）。
// ============================================================================
const _kMorphPathSteps = 90;

class _MorphSet {
  const _MorphSet(this.id, this.morphs, this.scaleFactor);
  final int id;
  final List<Morph> morphs;
  final double scaleFactor;
}

var _nextMorphSetId = 0;
final _morphSetCache = <List<RoundedPolygon>, _MorphSet>{};
final _morphPathCache = <(int, int, int), Path>{};

_MorphSet _morphSetFor(List<RoundedPolygon> polygons) {
  return _morphSetCache.putIfAbsent(polygons, () {
    final morphs = <Morph>[];
    for (var i = 0; i < polygons.length; i++) {
      morphs.add(Morph(polygons[i], polygons[(i + 1) % polygons.length]));
    }
    return _MorphSet(_nextMorphSetId++, morphs, _calculateScaleFactor(polygons));
  });
}

Path _cachedMorphPath(
  List<Morph> morphs,
  int morphSetId,
  int morphIndex,
  double progress,
) {
  final step = (progress * _kMorphPathSteps).round().clamp(0, _kMorphPathSteps);
  return _morphPathCache.putIfAbsent(
    (morphSetId, morphIndex, step),
    () => morphs[morphIndex].toPath(progress: step / _kMorphPathSteps),
  );
}

/// 计算把多边形缩放进容器时的比例因子（考虑旋转后的最大外接框，避免裁剪）。
double _calculateScaleFactor(List<RoundedPolygon> polygons) {
  var scaleFactor = 1.0;
  final bounds = List<double>.filled(4, 0);
  final maxBounds = List<double>.filled(4, 0);
  for (final polygon in polygons) {
    polygon
      ..calculateBounds(bounds: bounds)
      ..calculateMaxBounds(maxBounds);
    final scaleX = (bounds[2] - bounds[0]) / (maxBounds[2] - maxBounds[0]);
    final scaleY = (bounds[3] - bounds[1]) / (maxBounds[3] - maxBounds[1]);
    scaleFactor = math.min(scaleFactor, math.max(scaleX, scaleY));
  }
  return scaleFactor;
}

/// App-wide Material 3 Expressive 加载指示器。
///
/// 兼容包装层：保持既有调用点不变；内部使用 `material_new_shapes`，并对形变几何
/// 做跨实例缓存（Morph 匹配 + Path 量化）。
class M3ELoadingIndicator extends StatelessWidget {
  const M3ELoadingIndicator({
    super.key,
    this.size,
    this.color,
    this.containerColor,
    this.semanticsLabel,
  }) : contained = false;

  const M3ELoadingIndicator.contained({
    super.key,
    this.size,
    this.color,
    this.containerColor,
    this.semanticsLabel,
  }) : contained = true;

  /// 组件盒子尺寸。默认 Material 3 的 48dp 容器。
  final double? size;

  /// 活动指示器颜色。默认 `colorScheme.primary`，contained 变体为
  /// `colorScheme.onPrimaryContainer`。
  final Color? color;

  /// contained 变体的容器颜色。
  final Color? containerColor;

  /// 无障碍标签。
  final String? semanticsLabel;

  /// 是否渲染 Material 3 contained 变体。
  final bool contained;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? _packageContainerSize;
    final packageDimension = dimension / _packageActiveIndicatorScale;
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor =
        color ??
        (contained ? colorScheme.onPrimaryContainer : colorScheme.primary);

    final indicator = _LoadingIndicatorCore(
      contained: contained,
      activeIndicatorColor: activeColor,
      containerColor:
          containerColor ??
          (contained ? colorScheme.primaryContainer : Colors.transparent),
      semanticsLabel: semanticsLabel ?? 'Loading',
    );

    return SizedBox.square(
      dimension: dimension,
      child: OverflowBox(
        minWidth: packageDimension,
        maxWidth: packageDimension,
        minHeight: packageDimension,
        maxHeight: packageDimension,
        child: SizedBox.square(dimension: packageDimension, child: indicator),
      ),
    );
  }
}

class _LoadingIndicatorCore extends StatefulWidget {
  const _LoadingIndicatorCore({
    required this.contained,
    required this.activeIndicatorColor,
    required this.containerColor,
    required this.semanticsLabel,
  });

  final bool contained;
  final Color activeIndicatorColor;
  final Color containerColor;
  final String semanticsLabel;

  @override
  State<_LoadingIndicatorCore> createState() => _LoadingIndicatorCoreState();
}

class _LoadingIndicatorCoreState extends State<_LoadingIndicatorCore>
    with SingleTickerProviderStateMixin {
  final _globalAngle = ValueNotifier<double>(0);
  final _morphIndex = ValueNotifier<int>(0);

  // 形变几何来自跨实例缓存（含昂贵的 Morph 匹配与 scaleFactor，只算一次）。
  final _MorphSet _morphSet = _morphSetFor(_indeterminatePolygons);

  late final AnimationController _controller;

  late final _rotation = Tween<double>(begin: 0, end: 1).animate(_controller);

  late final _scale =
      TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 1, end: 1.125),
              weight: 200 / 350,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 1.125, end: 1),
              weight: 150 / 350,
            ),
          ])
          .chain(CurveTween(curve: const Interval(300 / 650, 650 / 650)))
          .animate(_controller);

  late final _morphProgress = Tween<double>(begin: 0, end: 1)
      .chain(
        CurveTween(
          curve: const Interval(300 / 650, 550 / 650, curve: Curves.easeOut),
        ),
      )
      .animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 650),
        )
        ..addStatusListener(_statusListener)
        ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _morphIndex.dispose();
    _globalAngle.dispose();
    super.dispose();
  }

  void _statusListener(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _globalAngle.value =
        (_globalAngle.value + _kSingleRotationAngle) % _kFullRotationAngle;
    _morphIndex.value = (_morphIndex.value + 1) % _morphSet.morphs.length;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _kContainerSize,
          minHeight: _kContainerSize,
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: widget.contained
                ? _ContainerPainter(containerColor: widget.containerColor)
                : null,
            foregroundPainter: _ActiveIndicatorPainter(
              activeIndicatorColor: widget.activeIndicatorColor,
              morphScaleFactor: _morphSet.scaleFactor,
              morphs: _morphSet.morphs,
              morphSetId: _morphSet.id,
              morphIndex: _morphIndex,
              globalAngle: _globalAngle,
              rotation: _rotation,
              scale: _scale,
              morphProgress: _morphProgress,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContainerPainter extends CustomPainter {
  const _ContainerPainter({required this.containerColor});

  final Color containerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(rect, Paint()..color = containerColor);
  }

  @override
  bool shouldRepaint(_ContainerPainter oldDelegate) =>
      oldDelegate.containerColor != containerColor;
}

class _ActiveIndicatorPainter extends CustomPainter {
  _ActiveIndicatorPainter({
    required this.activeIndicatorColor,
    required this.morphScaleFactor,
    required this.morphs,
    required this.morphSetId,
    required this.morphIndex,
    required this.globalAngle,
    required this.rotation,
    required this.scale,
    required this.morphProgress,
  }) : super(
         repaint: Listenable.merge([
           morphIndex,
           globalAngle,
           rotation,
           scale,
           morphProgress,
         ]),
       );

  final Color activeIndicatorColor;
  final double morphScaleFactor;
  final List<Morph> morphs;
  final int morphSetId;
  final ValueListenable<int> morphIndex;
  final ValueListenable<double> globalAngle;
  final Animation<double> rotation;
  final Animation<double> scale;
  final Animation<double> morphProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final angle =
        globalAngle.value +
        _kLinearRotationAngle * rotation.value +
        _kMorphRotationAngle * morphProgress.value;

    // 每帧退化成一次 Path 查表（跨实例、跨帧共享）。
    final path = _cachedMorphPath(
      morphs,
      morphSetId,
      morphIndex.value,
      morphProgress.value,
    );

    final scaleFactor = morphScaleFactor * _kActiveIndicatorScale * scale.value;
    final remainingScaleFactor = 1 - scaleFactor;

    final halfWidth = rect.width / 2;
    final halfHeight = rect.height / 2;

    canvas
      ..save()
      ..translate(halfWidth, halfHeight)
      ..rotate(angle)
      ..translate(-halfWidth, -halfHeight)
      ..translate(
        halfWidth * remainingScaleFactor,
        halfHeight * remainingScaleFactor,
      )
      ..scale(rect.width * scaleFactor, rect.height * scaleFactor)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = activeIndicatorColor,
      )
      ..translate(
        -halfWidth * remainingScaleFactor,
        -halfHeight * remainingScaleFactor,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_ActiveIndicatorPainter oldDelegate) =>
      oldDelegate.activeIndicatorColor != activeIndicatorColor ||
      oldDelegate.morphScaleFactor != morphScaleFactor ||
      oldDelegate.morphs != morphs ||
      oldDelegate.morphSetId != morphSetId ||
      oldDelegate.morphIndex != morphIndex ||
      oldDelegate.globalAngle != globalAngle ||
      oldDelegate.rotation != rotation ||
      oldDelegate.scale != scale ||
      oldDelegate.morphProgress != morphProgress;
}
