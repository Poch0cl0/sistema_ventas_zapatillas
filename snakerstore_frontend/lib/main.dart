import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/ui.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AppConfig.preview
          ? SneakerStoreApp(preview: true)
          : FirebaseBootstrap(),
    ),
  );
}

class FirebaseBootstrap extends StatefulWidget {
  const FirebaseBootstrap({super.key});
  @override
  State<FirebaseBootstrap> createState() => _FirebaseBootstrapState();
}

class _FirebaseBootstrapState extends State<FirebaseBootstrap> {
  late Future<void> initialization = initialize();
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await FirebaseAuth.instance.setLanguageCode('es');
    AppConfig.validateBaseUrl(AppConfig.apiBaseUrl);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: initialization,
    builder: (_, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const SneakerStoreApp();
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: storeTheme,
        home: Scaffold(
          body: SafeArea(
            child: snapshot.hasError
                ? EmptyState(
                    'No pudimos iniciar la aplicación',
                    'Comprueba tu conexión y vuelve a intentarlo.',
                    icon: Icons.cloud_off,
                    label: 'Reintentar',
                    action: () => setState(() => initialization = initialize()),
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: orange, size: 48),
                        SizedBox(height: 20),
                        Text(
                          'SNEAKERSTORE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                        SizedBox(height: 24),
                        CircularProgressIndicator(),
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
