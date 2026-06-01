import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_router.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const OpenAscentApp());
}

class OpenAscentApp extends StatelessWidget {
  const OpenAscentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Open Ascent',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppRouter(),
    );
  }
}
