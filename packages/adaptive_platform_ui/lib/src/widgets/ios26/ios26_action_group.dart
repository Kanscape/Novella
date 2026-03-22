import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../adaptive_action_group_item.dart';

/// Native iOS 26 grouped action control using a single platform view.
class IOS26ActionGroup extends StatefulWidget {
  const IOS26ActionGroup({
    super.key,
    required this.items,
    this.foregroundColor,
    this.height = 48,
    this.buttonHeight = 36,
    this.iconButtonWidth = 40,
    this.textButtonWidth = 68,
    this.iconSize = 18,
    this.itemSpacing = 0,
    this.showDividers = true,
    this.horizontalPadding = 12,
  });

  final List<AdaptiveActionGroupItem> items;
  final Color? foregroundColor;
  final double height;
  final double buttonHeight;
  final double iconButtonWidth;
  final double textButtonWidth;
  final double iconSize;
  final double itemSpacing;
  final bool showDividers;
  final double horizontalPadding;

  @override
  State<IOS26ActionGroup> createState() => _IOS26ActionGroupState();
}

class _IOS26ActionGroupState extends State<IOS26ActionGroup> {
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onItemTapped':
        final arguments = call.arguments;
        if (arguments is Map) {
          final index = arguments['index'] as int?;
          if (index != null && index >= 0 && index < widget.items.length) {
            widget.items[index].onPressed?.call();
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isIOS) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _estimatedWidth,
      height: widget.height,
      child: UiKitView(
        viewType: 'adaptive_platform_ui/ios26_action_group',
        creationParams: _buildCreationParams(context),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('adaptive_platform_ui/ios26_action_group_$id');
    _channel!.setMethodCallHandler(_handleMethodCall);
  }

  Map<String, dynamic> _buildCreationParams(BuildContext context) {
    return {
      'items': widget.items.map((item) => item.toNativeMap()).toList(),
      if (widget.foregroundColor != null)
        'foregroundColor': _colorToArgb(widget.foregroundColor!),
      'isDark': MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      'buttonHeight': widget.buttonHeight,
      'iconButtonWidth': widget.iconButtonWidth,
      'textButtonWidth': widget.textButtonWidth,
      'iconSize': widget.iconSize,
      'itemSpacing': widget.itemSpacing,
      'showDividers': widget.showDividers,
      'horizontalPadding': widget.horizontalPadding,
    };
  }

  double get _estimatedWidth {
    const dividerWidth = 1.0;
    var total = widget.horizontalPadding * 2;

    for (var index = 0; index < widget.items.length; index++) {
      final item = widget.items[index];
      final hasText = (item.title?.isNotEmpty ?? false);
      total += hasText ? widget.textButtonWidth : widget.iconButtonWidth;
      if (index != widget.items.length - 1) {
        total += widget.showDividers ? dividerWidth : widget.itemSpacing;
      }
    }

    return total;
  }

  int _colorToArgb(Color color) {
    return (((color.a * 255.0).round() & 0xFF) << 24) |
        (((color.r * 255.0).round() & 0xFF) << 16) |
        (((color.g * 255.0).round() & 0xFF) << 8) |
        ((color.b * 255.0).round() & 0xFF);
  }
}
