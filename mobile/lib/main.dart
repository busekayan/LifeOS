import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'screens/login_screen.dart';
import 'services/token_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthCheckScreen(),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool isLoading = true;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    checkSession();
  }

  Future<void> checkSession() async {
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();

    // Her iki token da yoksa direkt login ekranına gönder
    if (accessToken == null || refreshToken == null) {
      if (!mounted) return;
      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });
      return;
    }

    try {
      // Uygulama açıldığında refresh token ile yeni access token almayı dene
      final response = await http.post(
        Uri.parse("http://10.0.2.2:3000/users/refresh"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refreshToken": refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data["accessToken"];

        // Yeni access token'ı kaydet, refresh token aynı kalabilir
        await TokenStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: refreshToken,
        );

        if (!mounted) return;
        setState(() {
          isLoggedIn = true;
          isLoading = false;
        });
      } else {
        // Refresh başarısızsa tokenları temizle ve login ekranına dön
        await TokenStorage.clearTokens();

        if (!mounted) return;
        setState(() {
          isLoggedIn = false;
          isLoading = false;
        });
      }
    } catch (e) {
      // Sunucu veya ağ hatasında tokenları temizle ve login ekranına dön
      await TokenStorage.clearTokens();

      if (!mounted) return;
      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isLoggedIn) {
      return const Scaffold(
        body: Center(
          child: Text(
            'User session found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return const LoginScreen();
  }
}
