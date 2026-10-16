import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/cart_provider.dart';
import 'screens/store_screens.dart';
import 'services/firebase_service.dart' as app_services;
import 'widgets/app_logo.dart';

final firebaseService = app_services.FirebaseService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: const MrApacheApp(),
    ),
  );
}

class MrApacheApp extends StatefulWidget {
  const MrApacheApp({super.key});

  @override
  State<MrApacheApp> createState() => _MrApacheAppState();
}

class _MrApacheAppState extends State<MrApacheApp> {
  late final Future<FirebaseApp> _firebaseInitialization;

  @override
  void initState() {
    super.initState();
    _firebaseInitialization = Firebase.initializeApp();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mr. Apache Pizzería',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: FutureBuilder(
      future: _firebaseInitialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StartupErrorScreen(message: snapshot.error.toString());
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const StartupSplash();
        }
        return const AuthGate();
      },
    ),
  );
}

class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF09090B),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLogo(size: 220),
          SizedBox(height: 18),
          Text(
            'Mr. Apache Pizzería',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'La favorita en Huancayo, un rinconcito en San Carlos',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFFFC107)),
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(color: Color(0xFFC62828)),
        ],
      ),
    ),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: firebaseService.auth.authStateChanges(),
    builder: (context, authSnapshot) {
      if (authSnapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = authSnapshot.data;
      if (user == null) return const AuthScreen();
      if (user.isAnonymous) {
        return const StoreShell(
          profile: {'name': 'Visitante', 'role': 'visitante'},
          userId: '',
        );
      }
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firebaseService.firestore
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.hasError) {
            return StartupErrorScreen(
              message: profileSnapshot.error.toString(),
            );
          }
          if (!profileSnapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final profile = profileSnapshot.data!;
          if (!profile.exists) {
            return StartupErrorScreen(
              message:
                  'No se encontró el perfil de tu cuenta. Contacta al local.',
            );
          }
          return StoreShell(profile: profile.data()!, userId: user.uid);
        },
      );
    },
  );
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppTheme.red),
            const SizedBox(height: 16),
            const Text(
              'No se pudo iniciar Mr. Apache',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configura Firebase para Android (google-services.json) '
              'y vuelve a iniciar la aplicación.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SelectableText(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
