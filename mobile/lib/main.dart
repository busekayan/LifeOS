import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config/api_config.dart';
import 'navigation/no_transition_page_route.dart';
import 'screens/budget_screen.dart';
import 'screens/diary_screen.dart';
import 'screens/discovery_screen.dart';
import 'screens/home_screen.dart';
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
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case "/home":
            return NoTransitionPageRoute(
              builder: (context) => const HomePage(),
            );
          case "/explore":
            return NoTransitionPageRoute(
              builder: (context) => const DiscoveryPage(),
            );
          case "/daily":
            return NoTransitionPageRoute(
              builder: (context) => const DailyScreen(),
            );
          case "/budget":
            return NoTransitionPageRoute(
              builder: (context) => const BudgetScreen(),
            );
        }

        return null;
      },
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

    // İki token da yoksa kullanıcı giriş yapmamış kabul edilir.
    if ((accessToken == null || accessToken.isEmpty) &&
        (refreshToken == null || refreshToken.isEmpty)) {
      if (!mounted) return;
      setState(() {
        isLoggedIn = false;
        isLoading = false;
      });
      return;
    }

    // 1) Önce access token geçerli mi kontrol et.
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        final meResponse = await http
            .get(
              ApiConfig.uri("/users/me"),
              headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $accessToken",
              },
            )
            .timeout(const Duration(seconds: 10));

        if (meResponse.statusCode == 200) {
          if (!mounted) return;
          setState(() {
            isLoggedIn = true;
            isLoading = false;
          });
          return;
        }
      } on TimeoutException {
        // Timeout olursa aşağıda refresh denenecek.
      } catch (_) {
        // Access doğrulama başarısızsa aşağıda refresh denenecek.
      }
    }

    // 2) Access token geçersizse refresh token ile yeni token almayı dene.
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final refreshResponse = await http
            .post(
              ApiConfig.uri("/users/refresh"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"refreshToken": refreshToken}),
            )
            .timeout(const Duration(seconds: 10));

        if (refreshResponse.statusCode == 200) {
          final refreshData = jsonDecode(refreshResponse.body);

          final dynamic rawAccessToken = refreshData["accessToken"];
          final dynamic rawRefreshToken = refreshData["refreshToken"];

          final String? newAccessToken = rawAccessToken is String
              ? rawAccessToken
              : null;

          final String newRefreshToken =
              rawRefreshToken is String && rawRefreshToken.isNotEmpty
              ? rawRefreshToken
              : refreshToken;

          // Refresh başarılı görünse bile access token düzgün dönmediyse kullanıcıyı içeri alma.
          if (newAccessToken == null || newAccessToken.isEmpty) {
            await TokenStorage.clearTokens();

            if (!mounted) return;
            setState(() {
              isLoggedIn = false;
              isLoading = false;
            });
            return;
          }

          // Yeni tokenları kaydet.
          await TokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          // 3) Yeni access token ile kullanıcıyı tekrar doğrula.
          final meResponse = await http
              .get(
                ApiConfig.uri("/users/me"),
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer $newAccessToken",
                },
              )
              .timeout(const Duration(seconds: 10));

          if (meResponse.statusCode == 200) {
            if (!mounted) return;
            setState(() {
              isLoggedIn = true;
              isLoading = false;
            });
            return;
          }
        }
      } on TimeoutException {
        // Aşağıda session geçersiz akışına düşecek.
      } catch (_) {
        // Aşağıda session geçersiz akışına düşecek.
      }
    }

    // 4) Buraya geldiyse session geçersizdir.
    await TokenStorage.clearTokens();

    if (!mounted) return;
    setState(() {
      isLoggedIn = false;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isLoggedIn) {
      return const HomePage();
    }

    return const LoginScreen();
  }
}
