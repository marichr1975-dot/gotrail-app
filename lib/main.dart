
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoTrApp());
}

class GoTrApp extends StatelessWidget {
  const GoTrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoTr-AI 6.5',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F9448),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor:
            const Color(0xFFF7F6F2),
      ),
      home: const HomeScreen(),
    );
  }
}
