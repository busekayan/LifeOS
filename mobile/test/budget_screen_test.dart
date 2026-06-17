import 'dart:async';
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

Map<String, Object?> groupJson({
  required int id,
  required String name,
  Object? expenses = const <Map<String, Object?>>[],
  Object? settlementSummary,
}) {
  return {
    "id": id,
    "name": name,
    "members": [
      friendJson(id: 7, firstName: "Buse", email: "buse@example.com"),
      friendJson(id: 12, firstName: "Ece", email: "ece@example.com"),
    ],
    "expenses": expenses,
    "settlement_summary": settlementSummary,
  };
}

Map<String, Object?> sharedExpenseJson({
  required int id,
  required String title,
  required int amount,
  List<int> participantIds = const [7, 12],
}) {
  Map<String, Object?> participantJson(int participantId) {
    final friend = participantId == 12
        ? friendJson(id: 12, firstName: "Ece", email: "ece@example.com")
        : friendJson(id: 7, firstName: "Buse", email: "buse@example.com");

    return {...friend, "share_amount": amount / participantIds.length};
  }

  return {
    "id": id,
    "title": title,
    "amount": amount,
    "expense_date": "2026-06-13",
    "paid_by_user": friendJson(
      id: 7,
      firstName: "Buse",
      email: "buse@example.com",
    ),
    "participants": participantIds.map(participantJson).toList(),
  };
}

Map<String, Object?> settlementSummaryJson({
  int amount = 150,
  int paidAmount = 300,
  int payerOwedShare = 150,
  int participantOwedShare = 150,
}) {
  return {
    "members": [
      {
        ...friendJson(id: 7, firstName: "Buse", email: "buse@example.com"),
        "paid_amount": paidAmount,
        "owed_share": payerOwedShare,
        "balance": paidAmount - payerOwedShare,
      },
      {
        ...friendJson(id: 12, firstName: "Ece", email: "ece@example.com"),
        "paid_amount": 0,
        "owed_share": participantOwedShare,
        "balance": -participantOwedShare,
      },
    ],
    "settlements": [
      {
        "from_user": friendJson(
          id: 12,
          firstName: "Ece",
          email: "ece@example.com",
        ),
        "to_user": friendJson(
          id: 7,
          firstName: "Buse",
          email: "buse@example.com",
        ),
        "amount": amount,
      },
    ],
  };
}

Map<String, Object?> invitationJson({
  required int id,
  required int requesterId,
  required String firstName,
  required String email,
}) {
  return {
    "id": id,
    "requester_id": requesterId,
    "first_name": firstName,
    "last_name": "Test",
    "email": email,
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
            if (url.path.endsWith("/friend-invitations")) {
              return jsonResponse({"invitations": []}, 200);
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

Future<void> setSmallTestScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 760);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets("shows loading state while budget data is loading", (
    tester,
  ) async {
    final pendingResponse = Completer<http.Response>();

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) =>
            pendingResponse.future,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

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
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({"invitations": []}, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(
              transactionsBody(
                incomeTotal: 5000,
                expenseTotal: 1200,
                sharedExpenseTotal: 300,
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

    expect(find.text("3500 TL"), findsOneWidget);
    expect(find.text("5000 TL"), findsOneWidget);
    expect(find.text("1200 TL"), findsOneWidget);
    expect(find.text("300 TL"), findsOneWidget);
    expect(find.text("Maaş"), findsOneWidget);
    expect(find.text("Market"), findsOneWidget);
    expect(find.text("+5000 TL"), findsOneWidget);
    expect(find.text("-450 TL"), findsOneWidget);
  });

  testWidgets("keeps long names and large amounts readable on a small screen", (
    tester,
  ) async {
    await setSmallTestScreen(tester);

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({
              "friends": [
                friendJson(
                  id: 12,
                  firstName: "CokUzunIsimliArkadas",
                  email: "uzunarkadas@example.com",
                ),
              ],
            }, 200);
          }
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({"invitations": []}, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(
              transactionsBody(
                incomeTotal: 987654321,
                expenseTotal: 123456789,
                sharedExpenseTotal: 22222222,
                transactions: [
                  transactionJson(
                    id: 2,
                    type: "expense",
                    title: "Cok uzun market alisverisi ve ev ihtiyaclari",
                    amount: 123456789,
                  ),
                ],
              ),
              200,
            );
          }
          return jsonResponse({
            "groups": [
              groupJson(
                id: 1,
                name: "Cok uzun ortak butce grubu adi",
                expenses: [
                  sharedExpenseJson(
                    id: 8,
                    title: "Cok uzun ortak gider basligi",
                    amount: 22222222,
                  ),
                ],
              ),
            ],
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("841975310 TL"), findsOneWidget);
    expect(find.text("-123456789 TL"), findsOneWidget);

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text("Kabul edilmiş arkadaşlar"), findsOneWidget);
    expect(find.textContaining("CokUzunIsimliArkadas"), findsOneWidget);
    expect(find.text("22222222 TL"), findsWidgets);
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
    expect(find.text("Başlık, tutar ve tarihi kontrol et."), findsOneWidget);
  });

  testWidgets("prevents letters in personal transaction amount", (
    tester,
  ) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(buildBudgetScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Gelir Ekle"));
    await tester.pumpAndSettle();

    final amountField = find.byType(TextField).at(1);
    await tester.enterText(amountField, "12abc34.567");
    await tester.pump();

    expect(find.text("1234.56"), findsOneWidget);
  });

  testWidgets("shows empty shared budget group state", (tester) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(buildBudgetScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();

    expect(find.text("Henüz ortak bütçe grubu yok"), findsOneWidget);
    expect(find.text("Davet Gönder"), findsOneWidget);
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
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({"invitations": []}, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(transactionsBody(), 200);
          }
          return jsonResponse({
            "groups": [
              groupJson(id: 1, name: "Ev Arkadaşları", expenses: null),
            ],
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();

    expect(find.text("Ev Arkadaşları"), findsOneWidget);

    await tester.tap(find.text("Ev Arkadaşları"));
    await tester.pumpAndSettle();

    expect(find.text("Bu grupta henüz ortak gider yok."), findsOneWidget);
  });

  testWidgets("renders shared group expenses", (tester) async {
    await setLargeTestScreen(tester);

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({"friends": []}, 200);
          }
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({"invitations": []}, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(transactionsBody(), 200);
          }
          return jsonResponse({
            "groups": [
              groupJson(
                id: 1,
                name: "Ev Arkadaşları",
                expenses: [
                  sharedExpenseJson(id: 8, title: "Market", amount: 300),
                ],
                settlementSummary: settlementSummaryJson(),
              ),
            ],
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Ev Arkadaşları"));
    await tester.pumpAndSettle();

    expect(find.text("Market"), findsOneWidget);
    expect(find.text("300 TL"), findsWidgets);
    expect(find.textContaining("Buse Test ödedi"), findsOneWidget);
    expect(find.text("Borç Durumu"), findsOneWidget);
    expect(find.textContaining("Ödedi 300 TL • Payı 150 TL"), findsOneWidget);
    expect(find.textContaining("Ödedi 0 TL • Payı 150 TL"), findsOneWidget);
    expect(
      find.textContaining("Ece Test, Buse Test kişisine 150 TL ödemeli"),
      findsOneWidget,
    );
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
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({"invitations": []}, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(transactionsBody(), 200);
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
    await tester.tap(find.byType(CheckboxListTile));
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

  testWidgets("adds a shared expense to a group", (tester) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({"friends": []}, 200);
          }
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({"invitations": []}, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(transactionsBody(), 200);
          }
          return jsonResponse({
            "groups": [groupJson(id: 1, name: "Ev Arkadaşları")],
          }, 200);
        },
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({
                "expense": sharedExpenseJson(
                  id: 9,
                  title: "Market",
                  amount: 300,
                  participantIds: [7],
                ),
              }, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Ev Arkadaşları"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Gider Ekle"));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), "Market");
    await tester.enterText(fields.at(1), "300");
    await tester.tap(find.widgetWithText(CheckboxListTile, "Ece Test"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Kaydet"));
    await tester.pumpAndSettle();

    final body = jsonDecode(postedBody as String);
    expect(body["title"], "Market");
    expect(body["amount"], 300);
    expect(body.containsKey("paid_by"), false);
    expect(body["participant_ids"], [7]);
    expect(find.text("Ortak gider eklendi."), findsOneWidget);
    expect(find.text("300 TL"), findsOneWidget);

    await tester.tap(find.text("Kişisel"));
    await tester.pumpAndSettle();

    expect(find.text("-300 TL"), findsOneWidget);
    expect(find.text("300 TL"), findsWidgets);
  });

  testWidgets("validates shared expense form fields", (tester) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({"friends": []}, 200);
          }
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({"invitations": []}, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(transactionsBody(), 200);
          }
          return jsonResponse({
            "groups": [groupJson(id: 1, name: "Ev Arkadaşları")],
          }, 200);
        },
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({}, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Ev Arkadaşları"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Gider Ekle"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Kaydet"));
    await tester.pumpAndSettle();

    expect(postedBody, isNull);
    expect(
      find.text("Başlık, tutar, tarih ve katılımcıları kontrol et."),
      findsOneWidget,
    );
  });

  testWidgets("sends a friend invitation by email", (tester) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({"message": "ok"}, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Davet Gönder"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "ece@example.com");
    await tester.tap(find.text("Gönder"));
    await tester.pumpAndSettle();

    expect(jsonDecode(postedBody as String), {"email": "ece@example.com"});
    expect(find.text("Arkadaş daveti gönderildi."), findsOneWidget);
  });

  testWidgets("shows accepted and pending friend states clearly", (
    tester,
  ) async {
    await setLargeTestScreen(tester);

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
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({
              "invitations": [
                invitationJson(
                  id: 3,
                  requesterId: 14,
                  firstName: "Ada",
                  email: "ada@example.com",
                ),
              ],
            }, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(transactionsBody(), 200);
          }
          return jsonResponse({"groups": []}, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();

    expect(find.text("Gelen davetler (1)"), findsOneWidget);
    expect(find.text("Kabul edilmiş arkadaşlar"), findsOneWidget);
    expect(find.text("Ece Test"), findsOneWidget);
    expect(find.text("Ada Test"), findsOneWidget);
  });

  testWidgets("shows pending friend invitation duplicate message", (
    tester,
  ) async {
    await setLargeTestScreen(tester);

    await tester.pumpWidget(
      buildBudgetScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              return jsonResponse({
                "message": "Friend invitation is already pending",
              }, 409);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Davet Gönder"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "ece@example.com");
    await tester.tap(find.text("Gönder"));
    await tester.pumpAndSettle();

    expect(
      find.text("Bu kişiye gönderilmiş bekleyen davet var."),
      findsOneWidget,
    );
  });

  testWidgets("accepts an incoming friend invitation", (tester) async {
    await setLargeTestScreen(tester);
    var accepted = false;
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({
              "friends": accepted
                  ? [
                      friendJson(
                        id: 12,
                        firstName: "Ece",
                        email: "ece@example.com",
                      ),
                    ]
                  : [],
            }, 200);
          }
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({
              "invitations": accepted
                  ? []
                  : [
                      invitationJson(
                        id: 3,
                        requesterId: 12,
                        firstName: "Ece",
                        email: "ece@example.com",
                      ),
                    ],
            }, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(transactionsBody(), 200);
          }
          return jsonResponse({"groups": []}, 200);
        },
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              accepted = true;
              return jsonResponse({
                "invitation": {"status": "accepted"},
              }, 200);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    expect(find.textContaining("Gelen davetler"), findsOneWidget);

    await tester.tap(find.byTooltip("Kabul Et"));
    await tester.pumpAndSettle();

    expect(jsonDecode(postedBody as String), {"action": "accept"});
    expect(find.text("Arkadaş daveti kabul edildi."), findsOneWidget);
    expect(find.text("Ece Test"), findsOneWidget);
  });

  testWidgets("rejects an incoming friend invitation", (tester) async {
    await setLargeTestScreen(tester);
    Object? postedBody;

    await tester.pumpWidget(
      buildBudgetScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path.endsWith("/friends")) {
            return jsonResponse({"friends": []}, 200);
          }
          if (url.path.endsWith("/friend-invitations")) {
            return jsonResponse({
              "invitations": [
                invitationJson(
                  id: 3,
                  requesterId: 12,
                  firstName: "Ece",
                  email: "ece@example.com",
                ),
              ],
            }, 200);
          }
          if (url.path.endsWith("/transactions")) {
            return jsonResponse(transactionsBody(), 200);
          }
          return jsonResponse({"groups": []}, 200);
        },
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedBody = body;
              return jsonResponse({
                "invitation": {"status": "rejected"},
              }, 200);
            },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Ortak"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Reddet"));
    await tester.pumpAndSettle();

    expect(jsonDecode(postedBody as String), {"action": "reject"});
    expect(find.text("Arkadaş daveti reddedildi."), findsOneWidget);
    expect(find.textContaining("Gelen davetler"), findsNothing);
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
