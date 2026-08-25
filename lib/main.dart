import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

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
      title: 'GoTr-Ail 11.8 TEST RICERCA',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // iPhone: aumenta la leggibilita del 25% senza cambiare Android.
        final scaler = Platform.isIOS ? const TextScaler.linear(1.25) : mq.textScaler;
        return MediaQuery(
          data: mq.copyWith(textScaler: scaler),
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
