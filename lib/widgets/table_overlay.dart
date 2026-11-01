import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 牌桌浮层外壳：半透明遮罩、可选的关闭按钮与居中的面板。
class TableOverlay extends StatelessWidget {
  const TableOverlay({
    super.key,
    required this.onLeave,
    required this.child,
    this.barrierOpacity = 0.45,
    this.showClose = true,
  });

  final VoidCallback onLeave;
  final Widget child;
  final double barrierOpacity;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: barrierOpacity),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
            if (showClose)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: onLeave,
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.white54,
                  tooltip: '离开',
                ),
              ),
            Center(child: child),
          ],
        ),
      ),
    );
  }
}

/// 浮层面板：统一的宽度上限、圆角、描边与阴影。
class TablePanel extends StatelessWidget {
  const TablePanel({
    super.key,
    required this.child,
    this.maxWidth = 340,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 18),
    this.gradient,
    this.radius = 18,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final width = math.min(maxWidth, MediaQuery.sizeOf(context).width - 40);
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? const Color(0xFF14301F) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: kGold.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.48),
            blurRadius: 26,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: child,
    );
  }
}
