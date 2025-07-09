import 'package:flutter/material.dart';

class FullScreenTextEditorScreen extends StatefulWidget {
  final String initialText;
  final String title;
  final String hintText;

  const FullScreenTextEditorScreen({
    super.key,
    required this.initialText,
    this.title = '编辑文本',
    this.hintText = '请输入内容...',
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