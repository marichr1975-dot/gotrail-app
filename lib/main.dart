import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const GoTrApp());
}

class GoTrApp extends StatelessWidget {
  const GoTrApp({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0C5FA8);
    const green = Color(0xFF2E8B57);
    return MaterialApp(
      title: 'GoTr-Ail 11.7',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        if (!Platform.isIOS) return child ?? const SizedBox.shrink();
        return MediaQuery(
          data: media.copyWith(textScaler: const TextScaler.linear(1.10)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue).copyWith(
          primary: blue,
          secondary: green,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
