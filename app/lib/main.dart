import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/core/theme/app_theme.dart';
import 'package:motomuse/firebase_options.dart';

/// App entry point. Initialises Firebase then wraps the widget tree
/// in a [ProviderScope] for Riverpod.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    const ProviderScope(
      child: MotoMuseApp(),
    ),
  );
}

/// Root widget. Configures routing and light/dark theming.
class MotoMuseApp extends StatelessWidget {
  /// Creates the root [MotoMuseApp] widget.
  const MotoMuseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MotoMuse',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
