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
  HttpDelete? httpDelete,
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
      httpDelete:
          httpDelete ??
          (Uri url, {Map<String, String>? headers}) async {
            return jsonResponse({"message": "deleted"}, 200);
          },
    ),
  );
}

void setLargeTestScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, Object?> habitJson({
  required int id,
  required String name,
  bool isCompleted = false,
  String? sourceTemplateId,
  String? sourceTemplateTitle,
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
    "source_template_id": sourceTemplateId,
    "source_template_title": sourceTemplateTitle,
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

  testWidgets("deletes a habit after confirmation", (tester) async {
    Uri? deleteUrl;

    await tester.pumpWidget(
      buildHomeScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({
            "habits": [habitJson(id: 1, name: "Read 20 pages")],
          }, 200);
        },
        httpDelete: (Uri url, {Map<String, String>? headers}) async {
          deleteUrl = url;
          return jsonResponse({"message": "deleted"}, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Alışkanlığı sil"));
    await tester.pumpAndSettle();

    expect(find.text("Alışkanlığı sil"), findsOneWidget);
    expect(
      find.text("'Read 20 pages' alışkanlığını silmek istediğine emin misin?"),
      findsOneWidget,
    );

    await tester.tap(find.text("Sil"));
    await tester.pumpAndSettle();

    expect(deleteUrl.toString(), contains("/habits/1"));
    expect(find.text("Read 20 pages"), findsNothing);
    expect(find.text("Alışkanlık silindi."), findsOneWidget);
    expect(
      find.text("Bu gün ve filtre için henüz alışkanlık yok."),
      findsOneWidget,
    );
  });

  testWidgets("keeps habit visible when delete request fails", (tester) async {
    await tester.pumpWidget(
      buildHomeScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({
            "habits": [habitJson(id: 1, name: "Read 20 pages")],
          }, 200);
        },
        httpDelete: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({"message": "error"}, 500);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Alışkanlığı sil"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Sil"));
    await tester.pumpAndSettle();

    expect(find.text("Read 20 pages"), findsOneWidget);
    expect(find.text("Alışkanlık silinemedi."), findsOneWidget);
  });

  testWidgets("deletes a template habit group after confirmation", (
    tester,
  ) async {
    setLargeTestScreen(tester);

    Uri? deleteUrl;

    await tester.pumpWidget(
      buildHomeScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({
            "habits": [
              habitJson(
                id: 1,
                name: "7 AM Uyanış",
                sourceTemplateId: "10",
                sourceTemplateTitle: "Sabah Savaşçısı",
              ),
              habitJson(
                id: 2,
                name: "10 dk Esneme",
                sourceTemplateId: "10",
                sourceTemplateTitle: "Sabah Savaşçısı",
              ),
              habitJson(id: 3, name: "Read 20 pages"),
            ],
          }, 200);
        },
        httpDelete: (Uri url, {Map<String, String>? headers}) async {
          deleteUrl = url;
          return jsonResponse({"message": "deleted", "deletedCount": 2}, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Sabah Savaşçısı"), findsOneWidget);
    expect(find.text("7 AM Uyanış"), findsOneWidget);
    expect(find.text("10 dk Esneme"), findsOneWidget);
    expect(find.text("Read 20 pages"), findsOneWidget);

    await tester.tap(find.byTooltip("Template planını sil"));
    await tester.pumpAndSettle();

    expect(find.text("Template planını sil"), findsOneWidget);
    expect(
      find.text(
        "'Sabah Savaşçısı' planındaki tüm alışkanlıkları silmek istediğine emin misin?",
      ),
      findsOneWidget,
    );

    await tester.tap(find.text("Sil"));
    await tester.pumpAndSettle();

    expect(deleteUrl.toString(), contains("/habit-templates/10"));
    expect(find.text("Sabah Savaşçısı"), findsNothing);
    expect(find.text("7 AM Uyanış"), findsNothing);
    expect(find.text("10 dk Esneme"), findsNothing);
    expect(find.text("Read 20 pages"), findsOneWidget);
    expect(find.text("Template planı silindi."), findsOneWidget);
  });

  testWidgets("keeps template habit group visible when delete request fails", (
    tester,
  ) async {
    setLargeTestScreen(tester);

    await tester.pumpWidget(
      buildHomeScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({
            "habits": [
              habitJson(
                id: 1,
                name: "7 AM Uyanış",
                sourceTemplateId: "10",
                sourceTemplateTitle: "Sabah Savaşçısı",
              ),
            ],
          }, 200);
        },
        httpDelete: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({"message": "error"}, 500);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Template planını sil"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Sil"));
    await tester.pumpAndSettle();

    expect(find.text("Sabah Savaşçısı"), findsOneWidget);
    expect(find.text("7 AM Uyanış"), findsOneWidget);
    expect(find.text("Template planı silinemedi."), findsOneWidget);
  });
}
