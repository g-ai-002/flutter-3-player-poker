import 'package:flutter/material.dart';

/// 内容页通用宽度约束：大屏下居中并限制行宽，避免文字被拉得过长。
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
