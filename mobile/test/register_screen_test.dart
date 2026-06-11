import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/register_screen.dart';

http.Response jsonResponse(Map<String, Object?> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {"content-type": "application/json; charset=utf-8"},
  );
}

Widget buildRegisterScreen({HttpPost? httpPost}) {
  return MaterialApp(
    home: RegisterScreen(
      httpPost:
          httpPost ??
          (Uri url, {Map<String, String>? headers, Object? body}) async {
            return http.Response("{}", 500);
          },
      navigateOnSuccess: false,
    ),
  );
}

Future<void> setLargeTestScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets("validates register form fields", (tester) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(buildRegisterScreen());

    await tester.tap(find.text("Kayıt Ol"));
    await tester.pump();

    expect(find.text("İsim zorunludur"), findsOneWidget);
    expect(find.text("Soyisim zorunludur"), findsOneWidget);
    expect(find.text("Email zorunludur"), findsOneWidget);
    expect(find.text("Şifre zorunludur"), findsOneWidget);
    expect(find.text("Şifre tekrarı zorunludur"), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), "buse");
    await tester.enterText(fields.at(1), "kayan");
    await tester.enterText(fields.at(2), "wrong-email");
    await tester.enterText(fields.at(3), "123");
    await tester.enterText(fields.at(4), "456");
    await tester.tap(find.text("Kayıt Ol"));
    await tester.pump();

    expect(find.text("Geçerli bir email girin"), findsOneWidget);
    expect(find.text("Şifre en az 6 karakter olmalıdır"), findsOneWidget);
    expect(find.text("Şifreler uyuşmuyor"), findsOneWidget);
  });

  testWidgets("submits register form with normalized user data", (
    tester,
  ) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildRegisterScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({"message": "created"}, 201);
            },
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), "buse");
    await tester.enterText(fields.at(1), "kayan");
    await tester.enterText(fields.at(2), "BUSE@EXAMPLE.COM");
    await tester.enterText(fields.at(3), "secret123");
    await tester.enterText(fields.at(4), "secret123");
    await tester.tap(find.text("Kayıt Ol"));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(jsonDecode(postedBody as String), {
      "firstName": "Buse",
      "lastName": "Kayan",
      "email": "buse@example.com",
      "password": "secret123",
    });
    expect(find.text("Kayıt başarılı."), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets("shows register error returned by API", (tester) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(
      buildRegisterScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              return jsonResponse({"message": "Bu email zaten kayıtlı"}, 400);
            },
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), "Buse");
    await tester.enterText(fields.at(1), "Kayan");
    await tester.enterText(fields.at(2), "buse@example.com");
    await tester.enterText(fields.at(3), "secret123");
    await tester.enterText(fields.at(4), "secret123");
    await tester.tap(find.text("Kayıt Ol"));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text("Bu email zaten kayıtlı"), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
