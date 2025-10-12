import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/services/prompt_service.dart';
import '../../domain/models/prompt_item.dart';
import 'code_editor/code_editor_view.dart';
import 'code_editor/editor_languages.dart';
import 'code_editor/editor_themes.dart';

/// Shows a fullscreen dialog for editing text with advanced code editor features.
Future<String?> showFullScreenTextEditor(
  BuildContext context, {
  required String initialText,
  int? chatId,
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
        chatId: chatId,
      );
    },
  );
}

class _PromptInjectionDialog extends ConsumerStatefulWidget {
  final int? chatId;
  final ValueChanged<String> onInject;

  const _PromptInjectionDialog({this.chatId, required this.onInject});

  @override
  ConsumerState<_PromptInjectionDialog> createState() =>
      _PromptInjectionDialogState();
}

class _PromptInjectionDialogState extends ConsumerState<_PromptInjectionDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.chatId != null ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promptService = ref.read(promptServiceProvider.notifier);
    // Watch the provider to rebuild when prompts change
    ref.watch(promptServiceProvider);

    final List<PromptItem> chatPrompts;
    final List<PromptItem> globalPrompts;

    if (widget.chatId != null) {
      final allPrompts = promptService.getItemsForChat(widget.chatId!);
      chatPrompts = allPrompts.where((p) => !p.isGlobal).toList();
      globalPrompts = allPrompts.where((p) => p.isGlobal).toList();
    } else {
      chatPrompts = [];
      final promptState = ref.watch(promptServiceProvider);
      globalPrompts = promptState.globalItems;
    }

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.chatId != null)
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '聊天专属'),
                  Tab(text: '全局'),
                ],
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: widget.chatId != null
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _PromptList(
                            items: chatPrompts, onInject: widget.onInject),
                        _PromptList(
                            items: globalPrompts, onInject: widget.onInject),
                      ],
                    )
                  : _PromptList(items: globalPrompts, onInject: widget.onInject),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('完成'),
        ),
      ],
    );
  }
}

class _PromptList extends StatelessWidget {
  final List<PromptItem> items;
  final ValueChanged<String> onInject;

  const _PromptList({required this.items, required this.onInject});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('没有可用的条目。'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final firstKeyword = item.keyword.split(',').first.trim();

        return ListTile(
          title: Text(firstKeyword.isNotEmpty ? firstKeyword : '(无关键词)'),
          subtitle: Text(
            item.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            onInject(item.text);
          },
        );
      },
    );
  }
}

class _FullScreenTextEditorDialog extends ConsumerStatefulWidget {
  final String initialText;
  final String title;
  final String? defaultValue;
  final String initialLanguage;
  final int? chatId;

  const _FullScreenTextEditorDialog({
    required this.initialText,
    required this.title,
    this.defaultValue,
    required this.initialLanguage,
    this.chatId,
  });

  @override
  ConsumerState<_FullScreenTextEditorDialog> createState() =>
      _FullScreenTextEditorDialogState();
}

class _FullScreenTextEditorDialogState
    extends ConsumerState<_FullScreenTextEditorDialog> {
  final GlobalKey<CodeEditorViewState> _editorKey =
      GlobalKey<CodeEditorViewState>();

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
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false), // Don't save
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
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _onClosePressed();
        },
        child: Scaffold(
          backgroundColor:
              editorThemes[editorState?.currentTheme ??
                      'monokai-sublime']?['root']
                  ?.backgroundColor,
          appBar: AppBar(
            title: null, // 1. Remove title
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: '关闭',
              onPressed: _onClosePressed, // 2. Add confirmation on exit
            ),
            actions: [
              // --- Prompt Injection ---
              IconButton(
                icon: const Icon(Icons.input),
                tooltip: '注入提示词',
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => _PromptInjectionDialog(
                      chatId: widget.chatId,
                      onInject: (text) => _insertText(text),
                    ),
                  );
                },
              ),
              // --- Language Selector ---
              PopupMenuButton<String>(
                icon: const Icon(Icons.code),
                tooltip: '切换语言',
                onSelected: (lang) {
                  editorState?.changeLanguage(
                    lang,
                    onLanguageChanged: () {
                      setState(() {});
                    },
                  );
                },
                itemBuilder: (context) => editorLanguages.keys
                    .map(
                      (lang) => CheckedPopupMenuItem<String>(
                        value: lang,
                        checked: editorState?.currentLanguage == lang,
                        child: Text(lang),
                      ),
                    )
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
                      const SnackBar(
                        content: Text('已恢复为默认值'),
                        duration: Duration(seconds: 2),
                      ),
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
                        Clipboard.setData(
                          ClipboardData(text: editorState!.currentText),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已复制到剪贴板'),
                            duration: Duration(seconds: 2),
                          ),
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
                    child: Text(
                      editorState?.isAllFolded ?? false ? '全部展开' : '全部折叠',
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'search_replace',
                    child: Text('搜索和替换'),
                  ),
                  const PopupMenuDivider(),
                  ...editorThemes.keys.map(
                    (theme) => CheckedPopupMenuItem<String>(
                      value: theme,
                      checked: editorState?.currentTheme == theme,
                      child: Text('主题: $theme'),
                    ),
                  ),
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
          body: Column(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             Expanded(
               child: CodeEditorView(
                 key: _editorKey,
                 initialText: widget.initialText,
                 initialLanguage: widget.initialLanguage,
               ),
             ),
             _buildSymbolToolbar(),
           ],
         ),
        ),
      ),
    );
  }

  void _insertText(String text) {
    editorState?.requestFocus();
    final editor = editorState?.controller;
    if (editor == null) return;

    var selection = editor.selection;
    var cursorPosition = selection.baseOffset;

    if (cursorPosition < 0) {
      cursorPosition = editor.text.length;
    }

    final currentText = editor.text;
    final textToInsert = '$text\n';
    final newText = currentText.substring(0, cursorPosition) +
        textToInsert +
        currentText.substring(cursorPosition);
    final newCursorPosition = cursorPosition + textToInsert.length;

    editor.text = newText;
    editor.selection = TextSelection.fromPosition(
      TextPosition(offset: newCursorPosition),
    );
    editorState?.requestFocus();
  }

  // --- Symbol Toolbar ---
  Widget _buildSymbolToolbar() {
    final symbols = [
      // Indentation
     '  ',
     // Quotes and Brackets
     '""',
     '()',
     '<>',
     '</>',
     '{}',
     '[]',
     // Comments and Slash
     '<!-- -->',
     '/* */',
     '/',
     // Markdown
     '# ',
     '## ',
     '### ',
     '- ',
     '*',
     '**',
     '_',
     '__',
     '``',
     '```',
     '---',
   ];

   return Material(
     color: Theme.of(context).bottomAppBarTheme.color,
     child: Wrap(
       alignment: WrapAlignment.start,
       spacing: 0,
       runSpacing: 0,
       children: symbols.map((symbol) {
         String displaySymbol;
         VoidCallback? onLongPressCallback;

         switch (symbol) {
           case '<!-- -->':
             displaySymbol = '<!--';
             break;
           case '/* */':
             displaySymbol = '/*';
             break;
           case '""':
             displaySymbol = '"';
             onLongPressCallback = () => _insertSymbol('“”');
             break;
           case '()':
             displaySymbol = '()';
             onLongPressCallback = () => _insertSymbol('（）');
             break;
           default:
             displaySymbol = symbol;
         }
         return SizedBox(
           width: 48,
           child: InkWell(
             onTap: () => _insertSymbol(symbol),
             onLongPress: onLongPressCallback,
             child: Center(
               child: Padding(
                 padding:
                     const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                 child: Text(
                   displaySymbol.trim().isEmpty ? 'Tab' : displaySymbol.trim(),
                   style: const TextStyle(fontSize: 16),
                 ),
               ),
             ),
           ),
         );
       }).toList(),
     ),
   );
 }

 void _insertSymbol(String symbol) {
  // Ensure the editor has focus before we attempt to modify it.
  editorState?.requestFocus();

  final editor = editorState?.controller;
  if (editor == null) {
    // If the editor is still not available, we can't proceed.
    return;
  }

   final currentText = editor.text;
   var selection = editor.selection;
   var cursorPosition = selection.baseOffset;

   // A cursor position of -1 indicates that the editor did not have focus.
   // When focus is gained, we'll default to placing the cursor at the end of the text.
   if (cursorPosition < 0) {
     cursorPosition = editor.text.length;
     selection = TextSelection.fromPosition(TextPosition(offset: cursorPosition));
   }

   String newText;
   int newCursorPosition;

   // Logic for inserting paired symbols around a selection
   if (selection.isCollapsed) {
     String textToInsert;
     int cursorOffset;

     switch (symbol) {
       case '""':
         textToInsert = '""';
         cursorOffset = 1;
         break;
       case '()':
         textToInsert = '()';
         cursorOffset = 1;
         break;
       case '“”':
         textToInsert = '“”';
         cursorOffset = 1;
         break;
       case '（）':
         textToInsert = '（）';
         cursorOffset = 1;
         break;
       case '<>':
         textToInsert = '<>';
         cursorOffset = 1;
         break;
       case '{}':
         textToInsert = '{}';
         cursorOffset = 1;
         break;
       case '[]':
         textToInsert = '[]';
         cursorOffset = 1;
         break;
       case '<!-- -->':
         textToInsert = '<!--  -->';
         cursorOffset = 5;
         break;
       case '/* */':
         textToInsert = '/**/';
         cursorOffset = 2;
         break;
       case '</>':
         textToInsert = '</>';
         cursorOffset = 2;
         break;
       case '**':
         textToInsert = '****';
         cursorOffset = 2;
         break;
       case '__':
         textToInsert = '____';
         cursorOffset = 2;
         break;
       case '``':
         textToInsert = '``';
         cursorOffset = 1;
         break;
       case '```':
         textToInsert = '```\n\n```';
         cursorOffset = 4;
         break;
       case '---':
         textToInsert = '---\n';
         cursorOffset = 4;
         break;
       default:
         textToInsert = symbol;
         cursorOffset = symbol.length;
     }
     newText = currentText.substring(0, cursorPosition) +
         textToInsert +
         currentText.substring(cursorPosition);
     newCursorPosition = cursorPosition + cursorOffset;
   } else {
     final selectedText = selection.textInside(currentText);
     String textToInsertBefore;
     String textToInsertAfter;

     switch (symbol) {
       case '""':
         textToInsertBefore = '"';
         textToInsertAfter = '"';
         break;
       case '()':
         textToInsertBefore = '(';
         textToInsertAfter = ')';
         break;
       case '“”':
         textToInsertBefore = '“';
         textToInsertAfter = '”';
         break;
       case '（）':
         textToInsertBefore = '（';
         textToInsertAfter = '）';
         break;
       case '<>':
         textToInsertBefore = '<';
         textToInsertAfter = '>';
         break;
       case '{}':
         textToInsertBefore = '{';
         textToInsertAfter = '}';
         break;
       case '[]':
         textToInsertBefore = '[';
         textToInsertAfter = ']';
         break;
       case '<!-- -->':
         textToInsertBefore = '<!-- ';
         textToInsertAfter = ' -->';
         break;
       case '/* */':
         textToInsertBefore = '/* ';
         textToInsertAfter = ' */';
         break;
       case '*':
         textToInsertBefore = '*';
         textToInsertAfter = '*';
         break;
       case '**':
         textToInsertBefore = '**';
         textToInsertAfter = '**';
         break;
       case '_':
         textToInsertBefore = '_';
         textToInsertAfter = '_';
         break;
       case '__':
         textToInsertBefore = '__';
         textToInsertAfter = '__';
         break;
       case '``':
         textToInsertBefore = '`';
         textToInsertAfter = '`';
         break;
       case '```':
         textToInsertBefore = '```\n';
         textToInsertAfter = '\n```';
         break;
      case '---':
        textToInsertBefore = '---\n';
        textToInsertAfter = '';
        break;
       default:
         textToInsertBefore = symbol;
         textToInsertAfter = '';
     }
     newText = currentText.substring(0, selection.start) +
         textToInsertBefore +
         selectedText +
         textToInsertAfter +
         currentText.substring(selection.end);

     newCursorPosition =
         selection.start + textToInsertBefore.length + selectedText.length;
   }

   editor.text = newText;
   editor.selection = TextSelection.fromPosition(
     TextPosition(offset: newCursorPosition),
   );

  // Ensure the editor keeps focus after the insertion.
  editorState?.requestFocus();
 }
}
