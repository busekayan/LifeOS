import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const LifeOSApp());
}

class LifeOSApp extends StatelessWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LifeOS',
      home: const LoginScreen(),
    );
  }
}
