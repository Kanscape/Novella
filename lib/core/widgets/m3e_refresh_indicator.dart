import 'package:flutter/material.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';

class M3ERefreshIndicator extends StatefulWidget {
  const M3ERefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.elevation = 2.0,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.size = 40.0,
    this.color,
    this.containerColor,
  });

  final RefreshCallback onRefresh;
  final Widget child;
  final ScrollNotificationPredicate notificationPredicate;
  final String? semanticsLabel;
  final String? semanticsValue;
  final RefreshIndicatorTriggerMode triggerMode;
  final double elevation;
  final double displacement;
  final double edgeOffset;
  final double size;
  final Color? color;
  final Color? containerColor;

  @override
  State<M3ERefreshIndicator> createState() => _M3ERefreshIndicatorState();
}

class _M3ERefreshIndicatorState extends State<M3ERefreshIndicator> {
  RefreshIndicatorStatus? _status;
  AxisDirection? _axisDirection;

  bool get _showIndicator {
    return switch (_status) {
      RefreshIndicatorStatus.armed ||
      RefreshIndicatorStatus.snap ||
      RefreshIndicatorStatus.refresh => true,
      RefreshIndicatorStatus.drag ||
      RefreshIndicatorStatus.done ||
      RefreshIndicatorStatus.canceled ||
      null => false,
    };
  }

  bool get _indicatorAtTop => _axisDirection != AxisDirection.up;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) {
      return false;
    }

    final axisDirection = notification.metrics.axisDirection;
    if (axisDirection != AxisDirection.down &&
        axisDirection != AxisDirection.up) {
      return false;
    }

    if (_axisDirection == axisDirection) {
      return false;
    }

    setState(() => _axisDirection = axisDirection);
    return false;
  }

  void _handleStatusChange(RefreshIndicatorStatus? status) {
    if (_status == status) return;

    setState(() {
      _status = status;
      if (status == null) {
        _axisDirection = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final edgePosition =
        widget.edgeOffset + widget.displacement - widget.size / 2;
    final indicatorAtTop = _indicatorAtTop;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: _handleStatusChange,
          notificationPredicate: widget.notificationPredicate,
          semanticsLabel: widget.semanticsLabel,
          semanticsValue: widget.semanticsValue,
          triggerMode: widget.triggerMode,
          elevation: widget.elevation,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: widget.child,
          ),
        ),
        Positioned(
          top: indicatorAtTop ? edgePosition : null,
          bottom: indicatorAtTop ? null : edgePosition,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showIndicator ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedScale(
                scale: _showIndicator ? 1 : 0.92,
                duration: const Duration(milliseconds: 150),
                child: Center(
                  child: _showIndicator
                      ? M3ELoadingIndicator.contained(
                          size: widget.size,
                          color: widget.color,
                          containerColor: widget.containerColor,
                          semanticsLabel: widget.semanticsLabel ?? 'Refresh',
                        )
                      : SizedBox.square(dimension: widget.size),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
