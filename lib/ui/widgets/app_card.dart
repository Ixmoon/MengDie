import 'package:flutter/material.dart';

/// 一个带有预设样式的可复用卡片小部件。
///
/// 这个小部件封装了 [Card]，提供了统一的外边距、圆角和阴影，
/// 简化了在应用中创建一致卡片视图的过程。
class AppCard extends StatelessWidget {
  /// 卡片中显示的小部件。
  final Widget child;

  /// 卡片的背景颜色。如果为 null，则使用 [CardTheme.color]。
  final Color? color;

  /// 卡片的内边距。默认为 12.0。
  final EdgeInsetsGeometry? padding;

  /// 卡片的外边距。默认为垂直方向 8.0。
  final EdgeInsetsGeometry? margin;

  /// 点击卡片时的回调函数。
  final VoidCallback? onTap;

  /// Card 的形状。
  final ShapeBorder? shape;

  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.padding,
    this.margin,
    this.onTap,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    // 确定最终的内边距和外边距
    final finalPadding = padding ?? const EdgeInsets.all(12.0);
    final finalMargin = margin ?? const EdgeInsets.symmetric(vertical: 8.0);
    final finalShape = shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0));


    // 如果没有 onTap 回调，则只返回一个普通的 Card
    return Card(
      margin: finalMargin,
      color: color,
      shape: finalShape,
      clipBehavior: Clip.antiAlias, // 确保 InkWell 的水波纹效果不会超出圆角边界
      child: onTap != null
        ? InkWell(
            onTap: onTap,
            child: Padding(
              padding: finalPadding,
              child: child,
            ),
          )
        : Padding(
            padding: finalPadding,
            child: child,
          ),
    );
  }
}