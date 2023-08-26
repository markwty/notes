import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'overview_page.dart';

void main() {
  runApp(MyApp());
}

class FakeFocusIntent extends Intent {
  const FakeFocusIntent();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: OverviewPage(),//DemoApp(),
    debugShowCheckedModeBanner: false,
    shortcuts: Map<LogicalKeySet, Intent>.from(WidgetsApp.defaultShortcuts)
      ..addAll(<LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const FakeFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const FakeFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const FakeFocusIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const FakeFocusIntent(),
      }),
  );
}