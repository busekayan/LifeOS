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

Map<String, Object?> transactionJson({
  required int id,
  required String type,
  required String title,
  required int amount,
}) {
  return {
    "id": id,
    "type": type,
    "title": title,
    "amount": amount,
    "transaction_date": "2026-06-13",
    "note": null,
  };
}

Map<String, Object?> transactionsBody({
  int incomeTotal = 0,
  int expenseTotal = 0,
  int sharedExpenseTotal = 0,
  List<Map<String, Object?>> transactions = const [],
}) {
  return {
    "summary": {
      "income_total": incomeTotal,
      "expense_total": expenseTotal,
      "shared_expense_total": sharedExpenseTotal,
      "remaining_balance": incomeTotal - expenseTotal - sharedExpenseTotal,
    },
    "transactions": transactions,
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
            if (url.path.endsWith("/transactions")) {
              return jsonResponse(transactionsBody(), 200);
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
    expect(find.text("Son İşlemler"), findsOneWidget);
  });

  testWidgets("renders monthly personal summary and transactions", (
    tester,
  ) async {
    await setLargeTestScreen(tester);

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({"friends": []}, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(
              transactionsBody(
                incomeTotal: 5000,
                expenseTotal: 1200,
                transactions: [
                  transactionJson(
                    id: 1,
                    type: "income",
                    title: "Maaş",
                    amount: 5000,
                  ),
                  transactionJson(
                    id: 2,
                    type: "expense",
                    title: "Market",
                    amount: 450,
                  ),
                ],
              ),
              200,
            );
          }
          return jsonResponse({"groups": []}, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("3800 TL"), findsOneWidget);
    expect(find.text("5000 TL"), findsOneWidget);
    expect(find.text("1200 TL"), findsOneWidget);
    expect(find.text("Maaş"), findsOneWidget);
    expect(find.text("Market"), findsOneWidget);
    expect(find.text("+5000 TL"), findsOneWidget);
    expect(find.text("-450 TL"), findsOneWidget);
  });

  testWidgets("adds an income transaction", (tester) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({
                "transaction": transactionJson(
                  id: 10,
                  type: "income",
                  title: "Maaş",
                  amount: 5000,
                ),
              }, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Gelir Ekle"));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), "Maaş");
    await tester.enterText(fields.at(1), "5000");
    await tester.tap(find.text("Kaydet"));
    await tester.pumpAndSettle();

    final body = jsonDecode(postedBody as String);
    expect(body["type"], "income");
    expect(body["title"], "Maaş");
    expect(body["amount"], 5000);
    expect(find.text("İşlem eklendi."), findsOneWidget);
    expect(find.text("Maaş"), findsOneWidget);
    expect(find.text("5000 TL"), findsWidgets);
  });

  testWidgets("adds an expense transaction", (tester) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({
                "transaction": transactionJson(
                  id: 11,
                  type: "expense",
                  title: "Kahve",
                  amount: 95,
                ),
              }, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Gider Ekle"));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), "Kahve");
    await tester.enterText(fields.at(1), "95");
    await tester.tap(find.text("Kaydet"));
    await tester.pumpAndSettle();

    final body = jsonDecode(postedBody as String);
    expect(body["type"], "expense");
    expect(body["title"], "Kahve");
    expect(body["amount"], 95);
    expect(find.text("Kahve"), findsOneWidget);
    expect(find.text("-95 TL"), findsWidgets);
  });

  testWidgets("validates personal transaction form fields", (tester) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({}, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Gelir Ekle"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Kaydet"));
    await tester.pumpAndSettle();

    expect(postedBody, isNull);
    expect(find.text("İşlem bilgilerini kontrol et."), findsOneWidget);
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
