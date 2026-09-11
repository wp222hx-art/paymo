import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'state/app_state.dart';
import 'ui/pages/login_page.dart';
import 'ui/pages/shell_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..boot(),
      child: const XinguangApp(),
    ),
  );
}

class XinguangApp extends StatelessWidget {
  const XinguangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '新光云 · DebtFlow AI',
      debugShowCheckedModeBanner: false,
      theme: buildXgTheme(),
      home: Consumer<AppState>(
        builder: (_, s, __) {
          if (!s.booted) {
            return const Scaffold(
              backgroundColor: XgColors.navy,
              body: Center(child: CircularProgressIndicator(color: XgColors.gold)),
            );
          }
          return s.loggedIn ? const ShellPage() : const LoginPage();
        },
      ),
    );
  }
}
