import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'code_editor/code_editor_view.dart';
import 'code_editor/dropdown_selector.dart';
import 'code_editor/editor_languages.dart';
import 'code_editor/editor_themes.dart';

/// Shows a fullscreen dialog for editing text with advanced code editor features.
Future<String?> showFullScreenTextEditor(
  BuildContext context, {
  required String initialText,
  String title = '编辑文本',
  String? hintText = '请输入内容...',
  String? defaultValue,
  String initialLanguage = 'xml',
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return _FullScreenTextEditorDialog(
        initialText: initialText,
        title: title,
        defaultValue: defaultValue,
        initialLanguage: initialLanguage,
      );
    },
  );
}

class _FullScreenTextEditorDialog extends StatefulWidget {
  final String initialText;
  final String title;
  final String? defaultValue;
  final String initialLanguage;

  const _FullScreenTextEditorDialog({
    required this.initialText,
    required this.title,
    this.defaultValue,
    required this.initialLanguage,
  });

  @override
  State<_FullScreenTextEditorDialog> createState() => _FullScreenTextEditorDialogState();
}

class _FullScreenTextEditorDialogState extends State<_FullScreenTextEditorDialog> {
  final GlobalKey<CodeEditorViewState> _editorKey = GlobalKey<CodeEditorViewState>();

  CodeEditorViewState? get editorState => _editorKey.currentState;

  Future<void> _onClosePressed() async {
    if (!mounted) return;

    final hasChanges = editorState?.currentText != widget.initialText;

    if (hasChanges) {
      final result = await showDialog<bool?>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('保存更改?'),
          content: const Text('您想在退出前保存您的更改吗?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false), // Don't save
              child: const Text('不保存'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null), // Cancel
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true), // Save
              child: const Text('保存'),
            ),
          ],
        ),
      );

      if (result == true) {
        // Save and pop
        if (mounted) Navigator.of(context).pop(editorState!.currentText);
      } else if (result == false) {
        // Don't save and pop
        if (mounted) Navigator.of(context).pop();
      }
      // If result is null (cancel), do nothing.
    } else {
      // No changes, just pop
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          _onClosePressed();
        },
        child: Scaffold(
          backgroundColor: editorThemes[editorState?.currentTheme ?? 'monokai-sublime']?['root']?.backgroundColor,
          appBar: AppBar(
            title: null, // 1. Remove title
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: '关闭',
              onPressed: _onClosePressed, // 2. Add confirmation on exit
            ),
            actions: [
              // --- Language Selector ---
              PopupMenuButton<String>(
                icon: const Icon(Icons.code),
                tooltip: '切换语言',
                onSelected: (lang) {
                  editorState?.changeLanguage(lang, onLanguageChanged: () {
                    setState(() {});
                  });
                },
                itemBuilder: (context) => editorLanguages.keys
                    .map((lang) => CheckedPopupMenuItem<String>(
                          value: lang,
                          checked: editorState?.currentLanguage == lang,
                          child: Text(lang),
                        ))
                    .toList(),
              ),
              const SizedBox(width: 8),

              // --- Restore Default ---
              if (widget.defaultValue != null)
                IconButton(
                  icon: const Icon(Icons.restore),
                tooltip: '恢复默认值',
                onPressed: () {
                  editorState?.resetText(widget.defaultValue!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已恢复为默认值'), duration: Duration(seconds: 2)),
                  );
                },
              ),

            // --- More Options Menu ---
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'toggle_line_numbers':
                    editorState?.toggleLineNumbers();
                    break;
                  case 'toggle_folding_handles':
                    editorState?.toggleFoldingHandles();
                    break;
                  case 'toggle_word_wrap':
                    editorState?.toggleWordWrap();
                    break;
                  case 'copy_all':
                    if (editorState != null) {
                      Clipboard.setData(ClipboardData(text: editorState!.currentText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 2)),
                      );
                    }
                    break;
                  case 'toggle_fold_all':
                    editorState?.toggleFoldAll();
                    break;
                  case 'search_replace':
                    editorState?.toggleSearchView();
                    break;
                  default:
                    // Handle theme changes
                    if (editorThemes.keys.contains(value)) {
                      editorState?.changeTheme(value);
                      setState(() {}); // Rebuild to update theme background
                    }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                CheckedPopupMenuItem<String>(
                  value: 'toggle_line_numbers',
                  checked: editorState?.showLineNumbers ?? true,
                  child: const Text('显示行号'),
                ),
                CheckedPopupMenuItem<String>(
                  value: 'toggle_folding_handles',
                  checked: editorState?.showFoldingHandles ?? true,
                  child: const Text('显示代码折叠'),
                ),
                const PopupMenuDivider(),
                CheckedPopupMenuItem<String>(
                  value: 'toggle_word_wrap',
                  checked: editorState?.isWordWrapEnabled ?? false,
                  child: const Text('自动换行'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'copy_all',
                  child: Text('全部复制'),
                ),
                PopupMenuItem<String>(
                  value: 'toggle_fold_all',
                  child: Text(editorState?.isAllFolded ?? false ? '全部展开' : '全部折叠'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'search_replace',
                  child: Text('搜索和替换'),
                ),
                const PopupMenuDivider(),
                ...editorThemes.keys.map((theme) => CheckedPopupMenuItem<String>(
                      value: theme,
                      checked: editorState?.currentTheme == theme,
                      child: Text('主题: $theme'),
                    )),
              ],
              icon: const Icon(Icons.more_vert),
              tooltip: '更多选项',
            ),

            // --- Save ---
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: '保存',
              onPressed: () {
                if (editorState != null) {
                  Navigator.of(context).pop(editorState!.currentText);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        body: CodeEditorView(
          key: _editorKey,
          initialText: widget.initialText,
          initialLanguage: widget.initialLanguage,
        ),
      )),
    );
  }
}
