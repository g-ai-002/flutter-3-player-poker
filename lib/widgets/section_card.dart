import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 设置页与详情页共用的卡片外壳：金色小标题 + 内容。
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: surfacePanel(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kGold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

/// 标签 + 内容的一行：不传 [labelWidth] 时内容靠右，传入后内容在固定宽度后换行。
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.fontSize = 13,
  });

  final String label;
  final String value;
  final double? labelWidth;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inline = labelWidth == null;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (inline) const Spacer() else const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: inline ? TextAlign.end : TextAlign.start,
              style: TextStyle(fontSize: fontSize, color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
