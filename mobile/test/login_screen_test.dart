import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/login_screen.dart';

http.Response jsonResponse(Map<String, Object?> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {"content-type": "application/json; charset=utf-8"},
  );
}

Widget buildLoginScreen({HttpPost? httpPost, SaveTokens? saveTokens}) {
  return MaterialApp(
    home: LoginScreen(
      httpPost:
          httpPost ??
          (Uri url, {Map<String, String>? headers, Object? body}) async {
            return http.Response("{}", 500);
          },
      saveTokens:
          saveTokens ??
          ({
            required String accessToken,
            required String refreshToken,
          }) async {},
      navigateOnSuccess: false,
    ),
  );
}

void main() {
  testWidgets("validates login form fields", (tester) async {
    await tester.pumpWidget(buildLoginScreen());

    await tester.tap(find.text("Giriş Yap"));
    await tester.pump();

    expect(find.text("Email zorunludur"), findsOneWidget);
    expect(find.text("Şifre zorunludur"), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, "wrong-email");
    await tester.enterText(find.byType(TextFormField).last, "secret123");
    await tester.tap(find.text("Giriş Yap"));
    await tester.pump();

    expect(find.text("Geçerli bir email girin"), findsOneWidget);
  });

  testWidgets("submits login form and saves returned tokens", (tester) async {
    Object? postedBody;
    String? savedAccessToken;
    String? savedRefreshToken;

    await tester.pumpWidget(
      buildLoginScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;

              return jsonResponse({
                "accessToken": "access-token",
                "refreshToken": "refresh-token",
              }, 200);
            },
        saveTokens:
            ({
              required String accessToken,
              required String refreshToken,
            }) async {
              savedAccessToken = accessToken;
              savedRefreshToken = refreshToken;
            },
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      "BUSE@EXAMPLE.COM",
    );
    await tester.enterText(find.byType(TextFormField).last, "secret123");
    await tester.tap(find.text("Giriş Yap"));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(jsonDecode(postedBody as String), {
      "email": "buse@example.com",
      "password": "secret123",
    });
    expect(savedAccessToken, "access-token");
    expect(savedRefreshToken, "refresh-token");
    expect(find.text("Giriş başarılı"), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets("shows login error returned by API", (tester) async {
    await tester.pumpWidget(
      buildLoginScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              return jsonResponse({"message": "Email veya şifre hatalı"}, 400);
            },
      ),
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      "buse@example.com",
    );
    await tester.enterText(find.byType(TextFormField).last, "wrong-password");
    await tester.tap(find.text("Giriş Yap"));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text("Email veya şifre hatalı"), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
