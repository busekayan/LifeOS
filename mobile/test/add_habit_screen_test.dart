import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/add_habit_screen.dart';

http.Response jsonResponse(Map<String, Object?> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {"content-type": "application/json; charset=utf-8"},
  );
}

Widget buildAddHabitScreen({
  HttpPost? httpPost,
  GetAccessToken? getAccessToken,
}) {
  return MaterialApp(
    home: AddHabitScreen(
      getAccessToken: getAccessToken ?? () async => "access-token",
      httpPost:
          httpPost ??
          (Uri url, {Map<String, String>? headers, Object? body}) async {
            return jsonResponse({"habitId": 1}, 201);
          },
      popOnSuccess: false,
    ),
  );
}

Future<void> setLargeTestScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    500,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets("validates required habit name", (tester) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(buildAddHabitScreen());

    await scrollToText(tester, "Alışkanlığı Kaydet");
    await tester.tap(find.text("Alışkanlığı Kaydet"));
    await tester.pump();

    expect(find.text("Alışkanlık adı zorunludur"), findsOneWidget);

    await scrollToText(tester, "Örn: Günde 2 litre su iç");
    await tester.enterText(find.byType(TextFormField).first, "ab");
    await scrollToText(tester, "Alışkanlığı Kaydet");
    await tester.tap(find.text("Alışkanlığı Kaydet"));
    await tester.pump();

    expect(find.text("En az 3 karakter olmalı"), findsOneWidget);
  });

  testWidgets("validates target value when a goal type is selected", (
    tester,
  ) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(buildAddHabitScreen());

    await scrollToText(tester, "Dakika");
    await tester.tap(find.text("Dakika"));
    await tester.pump();

    await scrollToText(tester, "Alışkanlığı Kaydet");
    await tester.tap(find.text("Alışkanlığı Kaydet"));
    await tester.pump();

    expect(find.text("Hedef değeri zorunludur"), findsOneWidget);
  });

  testWidgets("submits habit form with selected options", (tester) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildAddHabitScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({"habitId": 12}, 201);
            },
      ),
    );

    await scrollToText(tester, "Örn: Günde 2 litre su iç");
    await tester.enterText(find.byType(TextFormField).first, "Read a book");
    await tester.enterText(find.byType(TextFormField).at(1), "Read at night");

    await scrollToText(tester, "Akşam");
    await tester.tap(find.text("Akşam"));
    await tester.pump();

    await scrollToText(tester, "Dakika");
    await tester.tap(find.text("Dakika"));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).last, "20");

    await scrollToText(tester, "Cmt");
    await tester.tap(find.text("Cmt"));
    await tester.pump();

    await scrollToText(tester, "Alışkanlığı Kaydet");
    await tester.tap(find.text("Alışkanlığı Kaydet"));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(jsonDecode(postedBody as String), {
      "name": "Read a book",
      "description": "Read at night",
      "period": "evening",
      "frequency_type": "weekly",
      "days": [1, 2, 3, 4, 5, 6],
      "target_value": 20,
      "goal_type": "minute",
    });
    expect(find.text("Alışkanlık başarıyla eklendi."), findsOneWidget);
  });

  testWidgets("shows backend error when habit creation fails", (tester) async {
    await setLargeTestScreen(tester);

    await tester.pumpWidget(
      buildAddHabitScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              return jsonResponse({"message": "Invalid period value"}, 400);
            },
      ),
    );

    await scrollToText(tester, "Örn: Günde 2 litre su iç");
    await tester.enterText(find.byType(TextFormField).first, "Read a book");

    await scrollToText(tester, "Alışkanlığı Kaydet");
    await tester.tap(find.text("Alışkanlığı Kaydet"));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text("Invalid period value"), findsOneWidget);
  });
}
