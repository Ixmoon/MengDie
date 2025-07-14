// --- 文件功能 ---
// 本文件定义了在文件夹内拖拽时，用于“返回上一级”的UI提示区域。
//
// --- 主要功能 ---
// 1. **视图适配**: 能根据 `isListView` 参数，渲染出适配列表视图或网格视图的不同样式。
// 2. **清晰指示**: 提供明确的图标和文本，引导用户将项目拖动到此区域以实现“上移”操作。

import 'package:flutter/material.dart';

/// “返回上一级”的拖放目标小部件
class MoveUpTarget extends StatelessWidget {
  final bool isListView;
  const MoveUpTarget({super.key, required this.isListView});

  @override
  Widget build(BuildContext context) {
    if (isListView) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        color: Theme.of(context).hoverColor,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_upward, size: 18),
            SizedBox(width: 8),
            Text('拖动到此处以上移'),
          ],
        ),
      );
    } else {
      return GridTile(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).hoverColor,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_upward, size: 24),
              SizedBox(height: 8),
              Text('移至上一级', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
  }
}