import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/discovery_screen.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/register_screen.dart';
import 'package:mobile/widgets/app_bottom_navigation_bar.dart';

http.Response jsonResponse(Map<String, Object?> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {"content-type": "application/json; charset=utf-8"},
  );
}

class TestPage extends StatelessWidget {
  final String title;

  const TestPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(title)));
  }
}

Future<void> setLargeTestScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets("successful login navigates to home", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          httpPost:
              (Uri url, {Map<String, String>? headers, Object? body}) async {
                return jsonResponse({
                  "accessToken": "access-token",
                  "refreshToken": "refresh-token",
                }, 200);
              },
          saveTokens:
              ({
                required String accessToken,
                required String refreshToken,
              }) async {},
          homeBuilder: (context) => const TestPage(title: "Home target"),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      "buse@example.com",
    );
    await tester.enterText(find.byType(TextFormField).last, "secret123");
    await tester.tap(find.text("Giriş Yap"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text("Home target"), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets("successful register navigates back to login", (tester) async {
    await setLargeTestScreen(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RegisterScreen(
                          httpPost:
                              (
                                Uri url, {
                                Map<String, String>? headers,
                                Object? body,
                              }) async {
                                return jsonResponse({
                                  "message": "created",
                                }, 201);
                              },
                        ),
                      ),
                    );
                  },
                  child: const Text("Open Register"),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text("Open Register"));
    await tester.pumpAndSettle();
    expect(find.text("Register"), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), "Buse");
    await tester.enterText(fields.at(1), "Kayan");
    await tester.enterText(fields.at(2), "buse@example.com");
    await tester.enterText(fields.at(3), "secret123");
    await tester.enterText(fields.at(4), "secret123");
    await tester.tap(find.text("Kayıt Ol"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text("Open Register"), findsOneWidget);
    expect(find.text("Register"), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets("bottom navigation switches routes", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          "/home": (context) => const TestPage(title: "Home route"),
          "/explore": (context) => const TestPage(title: "Explore route"),
          "/daily": (context) => const TestPage(title: "Daily route"),
        },
        home: const Scaffold(
          body: Text("Current page"),
          bottomNavigationBar: AppBottomNavigationBar(currentIndex: 0),
        ),
      ),
    );

    await tester.tap(find.text("Günlük"));
    await tester.pumpAndSettle();
    expect(find.text("Daily route"), findsOneWidget);
  });

  testWidgets("bottom navigation shows placeholder for unavailable sections", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          "/home": (context) => const TestPage(title: "Home route"),
          "/explore": (context) => const TestPage(title: "Explore route"),
          "/daily": (context) => const TestPage(title: "Daily route"),
        },
        home: const Scaffold(
          body: Text("Current page"),
          bottomNavigationBar: AppBottomNavigationBar(currentIndex: 0),
        ),
      ),
    );

    expect(find.text("Araçlar"), findsNothing);

    await tester.tap(find.text("Bütçe"));
    await tester.pump();
    expect(find.text("Bütçe ekranı yakında eklenecek."), findsOneWidget);
  });

  testWidgets("protected screen shows an error without token", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoveryPage(
          getAccessToken: () async => null,
          httpGet: (Uri url, {Map<String, String>? headers}) async {
            return jsonResponse({"templates": []}, 200);
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("Oturum bulunamadı."), findsOneWidget);
    expect(find.text("Tekrar dene"), findsOneWidget);
  });
}
