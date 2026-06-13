import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/budget_screen.dart';

http.Response jsonResponse(Map<String, Object?> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {"content-type": "application/json; charset=utf-8"},
  );
}

Map<String, Object?> friendJson({
  required int id,
  required String firstName,
  required String email,
}) {
  return {
    "id": id,
    "first_name": firstName,
    "last_name": "Test",
    "email": email,
  };
}

Map<String, Object?> groupJson({required int id, required String name}) {
  return {
    "id": id,
    "name": name,
    "members": [
      friendJson(id: 7, firstName: "Buse", email: "buse@example.com"),
      friendJson(id: 12, firstName: "Ece", email: "ece@example.com"),
    ],
  };
}

Widget buildBudgetScreen({
  HttpGet? httpGet,
  HttpPost? httpPost,
  GetAccessToken? getAccessToken,
}) {
  return MaterialApp(
    home: BudgetScreen(
      getAccessToken: getAccessToken ?? () async => "access-token",
      httpGet:
          httpGet ??
          (Uri url, {Map<String, String>? headers}) async {
            if (url.path.endsWith("/friends")) {
              return jsonResponse({"friends": []}, 200);
            }
            return jsonResponse({"groups": []}, 200);
          },
      httpPost:
          httpPost ??
          (Uri url, {Map<String, String>? headers, Object? body}) async {
            return jsonResponse({"group": groupJson(id: 1, name: "Ev")}, 201);
          },
    ),
  );
}

Future<void> setLargeTestScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets("shows personal budget summary layout", (tester) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(buildBudgetScreen());
    await tester.pumpAndSettle();

    expect(find.text("Bütçe"), findsWidgets);
    expect(find.text("Kişisel"), findsOneWidget);
    expect(find.text("Ortak"), findsOneWidget);
    expect(find.text("Kalan Bütçe"), findsOneWidget);
    expect(find.text("Gelir"), findsOneWidget);
    expect(find.text("Kişisel Gider"), findsOneWidget);
    expect(find.text("Ortak Gider Payın"), findsOneWidget);
    expect(find.text("Bu Ay"), findsOneWidget);
  });

  testWidgets("shows empty shared budget group state", (tester) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(buildBudgetScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();

    expect(find.text("Henüz ortak bütçe grubu yok"), findsOneWidget);
    expect(find.text("Grup Oluştur"), findsOneWidget);
  });

  testWidgets("renders shared budget groups", (tester) async {
    await setLargeTestScreen(tester);

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({"friends": []}, 200);
          }
          return jsonResponse({
            "groups": [groupJson(id: 1, name: "Ev Arkadaşları")],
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();

    expect(find.text("Ev Arkadaşları"), findsOneWidget);
    expect(find.text("Buse Test"), findsOneWidget);
    expect(find.text("Ece Test"), findsOneWidget);
  });

  testWidgets("creates a shared budget group with selected friends", (
    tester,
  ) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({
              "friends": [
                friendJson(id: 12, firstName: "Ece", email: "ece@example.com"),
              ],
            }, 200);
          }
          return jsonResponse({"groups": []}, 200);
        },
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({
                "group": groupJson(id: 4, name: "Ev Arkadaşları"),
              }, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Grup Oluştur"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "Ev Arkadaşları");
    await tester.tap(find.text("Ece Test"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Oluştur"));
    await tester.pumpAndSettle();

    expect(jsonDecode(postedBody as String), {
      "name": "Ev Arkadaşları",
      "memberIds": [12],
    });
    expect(find.text("Ortak bütçe grubu oluşturuldu."), findsOneWidget);
    expect(find.text("Ev Arkadaşları"), findsOneWidget);
  });

  testWidgets("shows error state when budget data cannot be loaded", (
    tester,
  ) async {
    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({"message": "error"}, 500);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Bütçe bilgileri alınamadı."), findsOneWidget);
    expect(find.text("Tekrar dene"), findsOneWidget);
  });
}
