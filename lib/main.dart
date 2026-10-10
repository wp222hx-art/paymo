import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/mall_state.dart';
import 'ui/mall/entry_pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => MallState()..boot(),
      child: const XinguangApp(),
    ),
  );
}

class XinguangApp extends StatelessWidget {
  const XinguangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '星光云 · 会花钱，也会轻松清偿',
      debugShowCheckedModeBanner: false,
      theme: buildXgTheme(),
      home: const RootRouter(),
    );
  }
}
