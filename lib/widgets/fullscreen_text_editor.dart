import 'package:flutter/material.dart';

class FullScreenTextEditorScreen extends StatefulWidget {
  final String initialText;
  final String title;
  final String hintText;
  final String? defaultValue; // 新增：用于恢复的默认值

  const FullScreenTextEditorScreen({
    super.key,
    required this.initialText,
    this.title = '编辑文本',
    this.hintText = '请输入内容...',
    this.defaultValue, // 新增
  });

  @override
  State<FullScreenTextEditorScreen> createState() => _FullScreenTextEditorScreenState();
}

class _FullScreenTextEditorScreenState extends State<FullScreenTextEditorScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.defaultValue != null)
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: '恢复默认值',
              onPressed: () {
                setState(() {
                  _controller.text = widget.defaultValue!;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已恢复为默认值'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: () {
              Navigator.of(context).pop(_controller.text);
            },
          ),
        ],
      ),
      body: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: null,
        expands: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16.0),
        ),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16),
      ),
    );
  }
}