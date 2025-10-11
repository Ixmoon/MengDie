import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'editor_languages.dart';
import 'editor_themes.dart';

class CodeEditorView extends StatefulWidget {
  final String initialText;
  final String initialLanguage;

  const CodeEditorView({
    super.key,
    required this.initialText,
    this.initialLanguage = 'xml',
  });

  @override
  State<CodeEditorView> createState() => CodeEditorViewState();
}

class CodeEditorViewState extends State<CodeEditorView> {
  // Editor State
  late final CodeController _controller;
  final _codeFieldFocusNode = FocusNode();

  // UI State
  String _currentLanguage = 'xml';
  String _currentTheme = 'monokai-sublime';
  bool _showLineNumbers = true;
  bool _showFoldingHandles = true;
  bool _isWordWrapEnabled = false;

  // Search and Replace State
  bool _isSearchVisible = false;
  bool _isAllFolded = false;
  bool _isFoldingInProgress = false;
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  List<Match> _searchResults = [];
  int _currentMatchIndex = -1;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.initialLanguage;
    _loadSettings();
    _controller = CodeController(
      text: widget.initialText,
      language: editorLanguages[_currentLanguage],
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = prefs.getString('editor_theme') ?? 'monokai-sublime';
      _showLineNumbers = prefs.getBool('editor_show_line_numbers') ?? true;
      _showFoldingHandles =
          prefs.getBool('editor_show_folding_handles') ?? true;
      _isWordWrapEnabled = prefs.getBool('editor_word_wrap') ?? false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _codeFieldFocusNode.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // --- Public Getters and Methods ---
  String get currentText => _controller.text;
  CodeController get controller => _controller;
  bool get isSearchVisible => _isSearchVisible;
  bool get isFoldingInProgress => _isFoldingInProgress;
  bool get isAllFolded => _isAllFolded;
  bool get showLineNumbers => _showLineNumbers;
  bool get showFoldingHandles => _showFoldingHandles;
  bool get isWordWrapEnabled => _isWordWrapEnabled;
  String get currentLanguage => _currentLanguage;
  String get currentTheme => _currentTheme;

  void resetText(String text) {
    setState(() {
      _controller.text = text;
    });
  }

  void toggleLineNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showLineNumbers = !_showLineNumbers;
      prefs.setBool('editor_show_line_numbers', _showLineNumbers);
    });
  }

  void toggleFoldingHandles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showFoldingHandles = !_showFoldingHandles;
      prefs.setBool('editor_show_folding_handles', _showFoldingHandles);
    });
  }

  void toggleWordWrap() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isWordWrapEnabled = !_isWordWrapEnabled;
      prefs.setBool('editor_word_wrap', _isWordWrapEnabled);
    });
  }

  void changeLanguage(String language, {VoidCallback? onLanguageChanged}) {
    setState(() {
      _currentLanguage = language;
      _controller.language = editorLanguages[_currentLanguage];
      _codeFieldFocusNode.requestFocus();
    });
    onLanguageChanged?.call();
  }

  void changeTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentTheme = theme;
      prefs.setString('editor_theme', _currentTheme);
      _codeFieldFocusNode.requestFocus();
    });
  }

  void toggleSearchView() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _clearSearch();
      }
    });
  }

  Future<void> toggleFoldAll() async {
    setState(() {
      _isFoldingInProgress = true;
      _isAllFolded = !_isAllFolded;
    });

    await _processFoldingBatches(shouldFold: _isAllFolded);

    if (mounted) {
      setState(() {
        _isFoldingInProgress = false;
      });
    }
  }

  // --- Search and Replace Logic ---
  void _clearSearch() {
    _searchController.clear();
    _replaceController.clear();
    setState(() {
      _searchResults = [];
      _currentMatchIndex = -1;
    });
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch();
      }
    });
  }

  void _performSearch() {
    final searchTerm = _searchController.text;
    if (searchTerm.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentMatchIndex = -1;
      });
      return;
    }
    final regex = RegExp(searchTerm, caseSensitive: false, multiLine: true);
    final matches = regex.allMatches(_controller.text).toList();
    setState(() {
      _searchResults = matches;
      _currentMatchIndex = -1;
      if (_searchResults.isNotEmpty) {
        _currentMatchIndex = 0;
        final match = _searchResults[0];
        _controller.selection = TextSelection(
          baseOffset: match.start,
          extentOffset: match.end,
        );
        _codeFieldFocusNode.requestFocus();
      }
    });
  }

  void _goToNextMatch() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchResults.length;
      final match = _searchResults[_currentMatchIndex];
      _controller.selection = TextSelection(
        baseOffset: match.start,
        extentOffset: match.end,
      );
      _codeFieldFocusNode.requestFocus();
    });
  }

  void _goToPreviousMatch() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _searchResults.length) %
          _searchResults.length;
      final match = _searchResults[_currentMatchIndex];
      _controller.selection = TextSelection(
        baseOffset: match.start,
        extentOffset: match.end,
      );
      _codeFieldFocusNode.requestFocus();
    });
  }

  void _performReplace() {
    if (_currentMatchIndex == -1 || _searchResults.isEmpty) return;
    final match = _searchResults[_currentMatchIndex];
    final replacement = _replaceController.text;
    _controller.text = _controller.text.replaceRange(
      match.start,
      match.end,
      replacement,
    );
    _performSearch();
  }

  void _performReplaceAll() {
    final searchTerm = _searchController.text;
    if (searchTerm.isEmpty) return;
    final replacement = _replaceController.text;
    _controller.text = _controller.text.replaceAll(
      RegExp(searchTerm, caseSensitive: false, multiLine: true),
      replacement,
    );
    _performSearch();
  }

  Future<void> _processFoldingBatches({
    required bool shouldFold,
    int batchSize = 100,
  }) async {
    final lineCount = _controller.code.lines.length;
    for (int i = 0; i < lineCount; i += batchSize) {
      final end = (i + batchSize > lineCount) ? lineCount : i + batchSize;
      for (int j = i; j < end; j++) {
        if (shouldFold) {
          _controller.foldAt(j);
        } else {
          _controller.unfoldAt(j);
        }
      }
      await Future.delayed(Duration.zero);
    }
  }

  // --- UI Builders ---
  Widget _buildSearchView() {
    final theme = Theme.of(context);
    final hasMatches = _searchResults.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(8),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: '搜索',
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: hasMatches ? _goToPreviousMatch : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                onPressed: hasMatches ? _goToNextMatch : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replaceController,
                  decoration: const InputDecoration(
                    labelText: '替换为',
                    isDense: true,
                  ),
                ),
              ),
              TextButton(
                onPressed: hasMatches ? _performReplace : null,
                child: const Text('替换'),
              ),
              TextButton(
                onPressed: hasMatches ? _performReplaceAll : null,
                child: const Text('全部'),
              ),
            ],
          ),
          if (_searchController.text.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  hasMatches
                      ? '${_currentMatchIndex + 1} / ${_searchResults.length}'
                      : '0 / 0',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Create a new theme data by merging the selected theme with our custom font styles.
    final themeStyles = Map<String, TextStyle>.from(
      editorThemes[_currentTheme]!,
    );
    final originalRootStyle = themeStyles['root'] ?? const TextStyle();
    themeStyles['root'] = originalRootStyle.copyWith(
      fontSize: 16,
      fontFamily: 'monospace',
    );
    final codeThemeData = CodeThemeData(styles: themeStyles);

    return Column(
      children: [
        if (_isSearchVisible) _buildSearchView(),
        Expanded(
          child: CodeTheme(
            data: codeThemeData,
            child: _isWordWrapEnabled
                ? Container(
                    color: themeStyles['root']?.backgroundColor,
                    child: TextField(
                      controller: _controller,
                      focusNode: _codeFieldFocusNode,
                      // The base style for the TextField should have a transparent background
                      // to avoid painting over the container's background, which causes the "stripes" effect.
                      style: themeStyles['root']?.copyWith(
                        backgroundColor: Colors.transparent,
                      ),
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(8.0),
                      ),
                    ),
                  )
                : CodeField(
                    expands: true,
                    focusNode: _codeFieldFocusNode,
                    controller: _controller,
                    gutterStyle: (_showLineNumbers || _showFoldingHandles)
                        ? GutterStyle(
                            showLineNumbers: _showLineNumbers,
                            showFoldingHandles: _showFoldingHandles,
                          )
                        : GutterStyle.none,
                  ),
          ),
        ),
      ],
    );
  }
}
