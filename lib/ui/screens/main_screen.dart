import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../providers/core_providers.dart';

class MainScreen extends ConsumerStatefulWidget {
  final Widget child;
  const MainScreen({super.key, required this.child});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleNavigation();
  }

  void _handleNavigation() {
    final location = GoRouterState.of(context).uri.toString();
    if (location == '/list') {
      ref.read(sharedPreferencesProvider).whenData((prefs) {
        prefs.remove('last_open_chat_id');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
    );
  }
}