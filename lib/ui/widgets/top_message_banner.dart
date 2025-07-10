import 'package:flutter/material.dart';

/// 一个在屏幕顶部显示临时消息的横幅 Widget。
class TopMessageBanner extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;
  final VoidCallback? onDismiss; // 点击关闭按钮的回调

  const TopMessageBanner({
    super.key,
    required this.message,
    this.backgroundColor,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // 如果没有消息，则返回一个空的 SizedBox，不占用空间
    if (message == null) {
      // 使用 AnimatedSwitcher 包裹 SizedBox.shrink() 以便动画消失
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SizeTransition(
            sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            axisAlignment: -1.0,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: const SizedBox.shrink(key: ValueKey<String?>('empty')), // 给空状态一个 key
      );
    }

    // 使用 AnimatedSwitcher 实现平滑的出现和消失动画
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300), // 动画持续时间
      transitionBuilder: (Widget child, Animation<double> animation) {
        // 使用 SizeTransition 和 FadeTransition 组合动画
        return SizeTransition(
          sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          axisAlignment: -1.0, // 从顶部展开
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      // key 很重要，确保 AnimatedSwitcher 知道何时内容发生变化
      child: KeyedSubtree(
        key: ValueKey<String?>(message), // 使用 message 作为 key
        child: Container(
          width: double.infinity, // 宽度撑满
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          // 移除底部 margin，让它紧贴 AppBar 或屏幕顶部
          // margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).colorScheme.secondaryContainer, // 使用主题颜色或传入的颜色
            // 可以添加阴影或其他装饰
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withOpacity(0.1),
            //     blurRadius: 4,
            //     offset: const Offset(0, 2),
            //   ),
            // ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer, // 确保文本颜色与背景对比度良好
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // 可选：添加一个关闭按钮
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 20.0), // Added const
                  // color for Icon can be set via IconButton's style if needed or let Theme handle it
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(), // 移除默认的 IconButton padding
                  tooltip: '关闭消息',
                  onPressed: onDismiss,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
