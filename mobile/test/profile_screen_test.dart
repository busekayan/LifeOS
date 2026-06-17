import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/profile_screen.dart';

http.Response jsonResponse(Object? body, int statusCode) {
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

Widget buildProfileScreen({
  HttpGet? httpGet,
  GetAccessToken? getAccessToken,
  ClearTokens? clearTokens,
  CurrentDate? currentDate,
}) {
  return MaterialApp(
    routes: {"/login": (context) => const TestPage(title: "Login route")},
    home: ProfileScreen(
      httpGet:
          httpGet ??
          (Uri url, {Map<String, String>? headers}) async {
            if (url.path == "/moods/month") {
              return jsonResponse({
                "moods": [
                  {"mood": "mutlu", "log_date": "2026-06-03"},
                  {"mood": "sakin", "log_date": "2026-06-16"},
                ],
              }, 200);
            }

            if (url.path == "/diaries") {
              return jsonResponse([
                {
                  "id": 21,
                  "content":
                      "Bugün kendimi daha sakin ve üretken hissettim. Sabah kısa bir yürüyüş iyi geldi.",
                  "date": "2026-06-15",
                },
                {
                  "id": 20,
                  "content": "Yoğun ama güzel bir gündü.",
                  "date": "2026-06-14",
                },
              ], 200);
            }

            if (url.path == "/habits/summary") {
              return jsonResponse({
                "summary": {
                  "totalPlanned": 12,
                  "completed": 8,
                  "missed": 4,
                  "completionRate": 67,
                  "days": [
                    {
                      "date": "2026-06-14",
                      "planned": 4,
                      "completed": 3,
                      "missed": 1,
                    },
                    {
                      "date": "2026-06-15",
                      "planned": 4,
                      "completed": 2,
                      "missed": 2,
                    },
                    {
                      "date": "2026-06-16",
                      "planned": 4,
                      "completed": 3,
                      "missed": 1,
                    },
                  ],
                },
              }, 200);
            }

            return jsonResponse({
              "user": {
                "id": 7,
                "firstName": "Buse",
                "lastName": "Kayan",
                "email": "buse@example.com",
              },
            }, 200);
          },
      getAccessToken: getAccessToken ?? () async => "access-token",
      clearTokens: clearTokens ?? () async {},
      currentDate: currentDate ?? () => DateTime(2026, 6, 16),
    ),
  );
}

void main() {
  testWidgets("shows loading state while profile data is loading", (
    tester,
  ) async {
    final pendingResponse = Completer<http.Response>();

    await tester.pumpWidget(
      buildProfileScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) =>
            pendingResponse.future,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("renders profile user information and logout action", (
    tester,
  ) async {
    final requestedUrls = <Uri>[];
    final requestedHeaders = <Map<String, String>?>[];

    await tester.pumpWidget(
      buildProfileScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          requestedUrls.add(url);
          requestedHeaders.add(headers);

          if (url.path == "/moods/month") {
            return jsonResponse({"moods": []}, 200);
          }

          if (url.path == "/diaries") {
            return jsonResponse([], 200);
          }

          if (url.path == "/habits/summary") {
            return jsonResponse({
              "summary": {
                "totalPlanned": 0,
                "completed": 0,
                "missed": 0,
                "completionRate": 0,
                "days": [],
              },
            }, 200);
          }

          return jsonResponse({
            "user": {
              "id": 7,
              "firstName": "Buse",
              "lastName": "Kayan",
              "email": "buse@example.com",
            },
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedUrls.map((url) => url.path), [
      "/users/me",
      "/moods/month",
      "/diaries",
      "/habits/summary",
    ]);
    expect(requestedUrls[1].queryParameters["year"], "2026");
    expect(requestedUrls[1].queryParameters["month"], "6");
    expect(requestedUrls[3].queryParameters["days"], "30");
    expect(requestedUrls[3].queryParameters["end_date"], "2026-06-16");
    expect(requestedHeaders.first?["Authorization"], "Bearer access-token");
    expect(requestedHeaders.last?["Authorization"], "Bearer access-token");
    expect(find.text("Profil"), findsWidgets);
    expect(find.text("Çıkış Yap"), findsOneWidget);
    expect(find.text("Buse Kayan"), findsOneWidget);
    expect(find.text("buse@example.com"), findsOneWidget);
    expect(find.text("Mood takvimi"), findsOneWidget);
    expect(find.text("Günlük geçmişi"), findsOneWidget);
  });

  testWidgets("renders monthly mood calendar and mood summary", (tester) async {
    await tester.pumpWidget(buildProfileScreen());
    await tester.pumpAndSettle();

    expect(find.text("Haziran 2026"), findsOneWidget);
    expect(find.text("Pzt"), findsOneWidget);
    expect(find.byKey(const ValueKey("mood-day-2026-06-03")), findsOneWidget);
    expect(find.byKey(const ValueKey("mood-day-2026-06-16")), findsOneWidget);
    expect(
      find.text("Renkli günlere dokunarak mood detayını görebilirsin."),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey("mood-day-2026-06-03")));
    await tester.pumpAndSettle();

    expect(find.text("3 Haziran: Mutlu"), findsOneWidget);
  });

  testWidgets("handles months with no mood data", (tester) async {
    await tester.pumpWidget(
      buildProfileScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path == "/moods/month") {
            return jsonResponse({"moods": []}, 200);
          }

          if (url.path == "/diaries") {
            return jsonResponse([], 200);
          }

          if (url.path == "/habits/summary") {
            return jsonResponse({
              "summary": {
                "totalPlanned": 0,
                "completed": 0,
                "missed": 0,
                "completionRate": 0,
                "days": [],
              },
            }, 200);
          }

          return jsonResponse({
            "user": {
              "id": 7,
              "firstName": "Buse",
              "lastName": "Kayan",
              "email": "buse@example.com",
            },
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Bu ay için mood kaydı yok."), findsOneWidget);
    expect(find.byKey(const ValueKey("mood-day-2026-06-16")), findsOneWidget);
  });

  testWidgets("renders recent diary entries and expands a diary preview", (
    tester,
  ) async {
    await tester.pumpWidget(buildProfileScreen());
    await tester.pumpAndSettle();

    expect(find.text("Günlük geçmişi"), findsOneWidget);
    expect(find.text("15 Haziran"), findsOneWidget);
    expect(find.text("14 Haziran"), findsOneWidget);
    expect(
      find.text(
        "Bugün kendimi daha sakin ve üretken hissettim. Sabah kısa bir yürüyüş iyi geldi.",
      ),
      findsOneWidget,
    );

    final diaryText = tester.widget<Text>(
      find.text(
        "Bugün kendimi daha sakin ve üretken hissettim. Sabah kısa bir yürüyüş iyi geldi.",
      ),
    );
    expect(diaryText.maxLines, 2);
    expect(diaryText.overflow, TextOverflow.ellipsis);

    await tester.ensureVisible(find.byKey(const ValueKey("diary-entry-21")));
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("diary-entry-21")));
    await tester.pumpAndSettle();

    final expandedDiaryText = tester.widget<Text>(
      find.text(
        "Bugün kendimi daha sakin ve üretken hissettim. Sabah kısa bir yürüyüş iyi geldi.",
      ),
    );
    expect(expandedDiaryText.maxLines, null);
    expect(expandedDiaryText.overflow, TextOverflow.visible);
  });

  testWidgets("shows empty diary state", (tester) async {
    await tester.pumpWidget(
      buildProfileScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path == "/moods/month") {
            return jsonResponse({"moods": []}, 200);
          }

          if (url.path == "/diaries") {
            return jsonResponse([], 200);
          }

          if (url.path == "/habits/summary") {
            return jsonResponse({
              "summary": {
                "totalPlanned": 0,
                "completed": 0,
                "missed": 0,
                "completionRate": 0,
                "days": [],
              },
            }, 200);
          }

          return jsonResponse({
            "user": {
              "id": 7,
              "firstName": "Buse",
              "lastName": "Kayan",
              "email": "buse@example.com",
            },
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Henüz günlük kaydın yok. Yazdıkların burada görünecek."),
      findsOneWidget,
    );
  });

  testWidgets("renders habit completion statistics", (tester) async {
    await tester.pumpWidget(buildProfileScreen());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();

    expect(find.text("Alışkanlık istatistikleri"), findsOneWidget);
    expect(find.text("%67"), findsOneWidget);
    expect(find.text("Tamamlanan"), findsOneWidget);
    expect(find.text("Kaçan"), findsOneWidget);
    expect(find.text("8"), findsWidgets);
    expect(find.text("4"), findsWidgets);
    expect(find.text("Tamamlandı"), findsOneWidget);
    expect(find.text("Kaçtı"), findsOneWidget);
  });

  testWidgets("shows empty habit statistics state", (tester) async {
    await tester.pumpWidget(
      buildProfileScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          if (url.path == "/moods/month") {
            return jsonResponse({"moods": []}, 200);
          }

          if (url.path == "/diaries") {
            return jsonResponse([], 200);
          }

          if (url.path == "/habits/summary") {
            return jsonResponse({
              "summary": {
                "totalPlanned": 0,
                "completed": 0,
                "missed": 0,
                "completionRate": 0,
                "days": [],
              },
            }, 200);
          }

          return jsonResponse({
            "user": {
              "id": 7,
              "firstName": "Buse",
              "lastName": "Kayan",
              "email": "buse@example.com",
            },
          }, 200);
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "İstatistik oluşturmak için henüz yeterli alışkanlık verisi yok.",
      ),
      findsOneWidget,
    );
  });

  testWidgets("shows error state when profile cannot be loaded", (
    tester,
  ) async {
    await tester.pumpWidget(
      buildProfileScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({"message": "error"}, 500);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Profil bilgileri alınamadı."), findsOneWidget);
    expect(find.text("Tekrar dene"), findsOneWidget);
  });

  testWidgets("shows session error when token is missing", (tester) async {
    await tester.pumpWidget(
      buildProfileScreen(getAccessToken: () async => null),
    );
    await tester.pumpAndSettle();

    expect(find.text("Oturum bulunamadı."), findsOneWidget);
  });

  testWidgets("logout clears tokens and redirects to login", (tester) async {
    var clearedTokens = false;

    await tester.pumpWidget(
      buildProfileScreen(
        clearTokens: () async {
          clearedTokens = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Çıkış Yap"));
    await tester.pumpAndSettle();

    expect(clearedTokens, true);
    expect(find.text("Login route"), findsOneWidget);
  });
}
