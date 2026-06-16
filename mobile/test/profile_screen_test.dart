import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/profile_screen.dart';

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

Widget buildProfileScreen({
  HttpGet? httpGet,
  GetAccessToken? getAccessToken,
  ClearTokens? clearTokens,
}) {
  return MaterialApp(
    routes: {"/login": (context) => const TestPage(title: "Login route")},
    home: ProfileScreen(
      httpGet:
          httpGet ??
          (Uri url, {Map<String, String>? headers}) async {
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
    Uri? requestedUrl;
    Map<String, String>? requestedHeaders;

    await tester.pumpWidget(
      buildProfileScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          requestedUrl = url;
          requestedHeaders = headers;

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

    expect(requestedUrl?.path, "/users/me");
    expect(requestedHeaders?["Authorization"], "Bearer access-token");
    expect(find.text("Profil"), findsWidgets);
    expect(find.text("Çıkış Yap"), findsOneWidget);
    expect(find.text("Buse Kayan"), findsOneWidget);
    expect(find.text("buse@example.com"), findsOneWidget);
    expect(find.text("Mood takvimi"), findsOneWidget);
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
