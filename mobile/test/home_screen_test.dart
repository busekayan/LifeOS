import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/home_screen.dart';

final testDate = DateTime(2026, 6, 11);

http.Response jsonResponse(Map<String, Object?> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {"content-type": "application/json; charset=utf-8"},
  );
}

Widget buildHomeScreen({
  HttpGet? httpGet,
  HttpPost? httpPost,
  GetAccessToken? getAccessToken,
}) {
  return MaterialApp(
    home: HomePage(
      initialDate: testDate,
      getAccessToken: getAccessToken ?? () async => "access-token",
      httpGet:
          httpGet ??
          (Uri url, {Map<String, String>? headers}) async {
            return jsonResponse({"habits": []}, 200);
          },
      httpPost:
          httpPost ??
          (Uri url, {Map<String, String>? headers, Object? body}) async {
            return jsonResponse({"completed": true}, 201);
          },
    ),
  );
}

Map<String, Object?> habitJson({
  required int id,
  required String name,
  bool isCompleted = false,
}) {
  return {
    "id": id,
    "name": name,
    "description": "Daily habit",
    "period": "all",
    "frequency_type": "weekly",
    "target_value": null,
    "goal_type": null,
    "current_value": isCompleted ? 1 : 0,
    "is_completed": isCompleted,
    "days": [4],
  };
}

void main() {
  testWidgets("shows loading state while habits are being fetched", (
    tester,
  ) async {
    final completer = Completer<http.Response>();

    await tester.pumpWidget(
      buildHomeScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) {
          return completer.future;
        },
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(jsonResponse({"habits": []}, 200));
  });

  testWidgets("shows empty state when there are no habits", (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();

    expect(
      find.text("Bu gün ve filtre için henüz alışkanlık yok."),
      findsOneWidget,
    );
  });

  testWidgets("renders habit list returned by the backend", (tester) async {
    await tester.pumpWidget(
      buildHomeScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({
            "habits": [habitJson(id: 1, name: "Read 20 pages")],
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Read 20 pages"), findsOneWidget);
    expect(find.text("Daily habit"), findsOneWidget);
    expect(find.text("Bugün için bekliyor"), findsOneWidget);
  });

  testWidgets("toggles habit completion", (tester) async {
    Object? postedBody;

    await tester.pumpWidget(
      buildHomeScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({
            "habits": [habitJson(id: 1, name: "Read 20 pages")],
          }, 200);
        },
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({"completed": true}, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
    await tester.pumpAndSettle();

    expect(jsonDecode(postedBody as String), {
      "habit_id": 1,
      "log_date": "2026-06-11",
    });
    expect(find.text("Tamamlandı"), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets("shows backend error state when habits cannot be loaded", (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHomeScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({"message": "error"}, 500);
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text("Alışkanlıklar alınamadı."), findsOneWidget);
  });
}
