import 'package:flutter/material.dart';
import 'core/store.dart';
import 'core/engine.dart';
import 'screens/home.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await AppStore.load();
    runApp(TalApp(store: store, engines: createEngines()));
  } catch (error) {
    runApp(
      MaterialApp(
        theme: talTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Mark(size: 64),
                  const SizedBox(height: 24),
                  const Text('Tal could not open its local library.'),
                  const SizedBox(height: 12),
                  SelectableText('$error'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TalApp extends StatelessWidget {
  final AppStore store;
  final EngineService engines;
  const TalApp({super.key, required this.store, required this.engines});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tal',
    debugShowCheckedModeBanner: false,
    theme: talTheme(),
    home: HomeScreen(store: store, engines: engines),
  );
}
