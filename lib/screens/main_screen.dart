import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class MainScreen extends ConsumerWidget {
  final Widget child;
  const MainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
    );
  }
}