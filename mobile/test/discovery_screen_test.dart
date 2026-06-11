import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/screens/discovery_screen.dart';

http.Response jsonResponse(Map<String, Object?> body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {"content-type": "application/json; charset=utf-8"},
  );
}

Map<String, Object?> templateJson({
  required int id,
  required String title,
  required String category,
  required int habitCount,
  bool isFeatured = false,
  bool isAdded = false,
}) {
  return {
    "id": id,
    "title": title,
    "description": "$title description",
    "image_url": "https://example.com/$id.jpg",
    "is_featured": isFeatured,
    "category": category,
    "habit_count": habitCount,
    "is_added": isAdded,
    "habits": [
      {"name": "First habit"},
      {"name": "Second habit"},
    ],
  };
}

Map<String, Object?> templatesBody() {
  return {
    "categories": ["Fitness", "Productivity", "Wellness"],
    "templates": [
      templateJson(
        id: 1,
        title: "Sabah Savaşçısı",
        category: "Fitness",
        habitCount: 5,
        isFeatured: true,
      ),
      templateJson(
        id: 2,
        title: "Derin Odaklanma",
        category: "Productivity",
        habitCount: 4,
      ),
      templateJson(
        id: 3,
        title: "Huzurlu Akşamlar",
        category: "Wellness",
        habitCount: 3,
        isAdded: true,
      ),
    ],
  };
}

Widget buildDiscoveryScreen({
  HttpGet? httpGet,
  HttpPost? httpPost,
  GetAccessToken? getAccessToken,
}) {
  return MaterialApp(
    home: DiscoveryPage(
      getAccessToken: getAccessToken ?? () async => "access-token",
      httpGet:
          httpGet ??
          (Uri url, {Map<String, String>? headers}) async {
            return jsonResponse(templatesBody(), 200);
          },
      httpPost:
          httpPost ??
          (Uri url, {Map<String, String>? headers, Object? body}) async {
            return jsonResponse({"addedCount": 4}, 201);
          },
    ),
  );
}

Future<void> setLargeTestScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> scrollToText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    600,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets("shows loading state while templates are being fetched", (
    tester,
  ) async {
    final completer = Completer<http.Response>();

    await tester.pumpWidget(
      buildDiscoveryScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) {
          return completer.future;
        },
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(jsonResponse(templatesBody(), 200));
  });

  testWidgets("renders template list, categories and card details", (
    tester,
  ) async {
    await setLargeTestScreen(tester);
    await tester.pumpWidget(buildDiscoveryScreen());
    await tester.pumpAndSettle();

    expect(find.text("Keşfet"), findsWidgets);
    expect(find.text("Tümü"), findsOneWidget);
    expect(find.text("Fitness"), findsWidgets);
    expect(find.text("Productivity"), findsWidgets);
    expect(find.text("Wellness"), findsWidgets);
    expect(find.text("Öne Çıkanlar"), findsOneWidget);
    expect(find.text("Sabah Savaşçısı"), findsOneWidget);
    expect(find.text("5 alışkanlık"), findsOneWidget);

    await scrollToText(tester, "Derin Odaklanma");

    expect(find.text("Derin Odaklanma"), findsOneWidget);
    expect(find.text("4 alışkanlık içeriyor"), findsOneWidget);
    expect(find.text("Productivity"), findsWidgets);
  });

  testWidgets("adds a template and shows success state", (tester) async {
    await setLargeTestScreen(tester);
    Uri? postedUrl;

    await tester.pumpWidget(
      buildDiscoveryScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedUrl = url;
              return jsonResponse({"addedCount": 4}, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await scrollToText(tester, "Derin Odaklanma");
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(postedUrl.toString(), contains("/habit-templates/2/add"));
    expect(find.text("4 alışkanlık listene eklendi!"), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);
  });

  testWidgets("shows already-added template state", (tester) async {
    await setLargeTestScreen(tester);
    Uri? postedUrl;

    await tester.pumpWidget(
      buildDiscoveryScreen(
        httpPost:
            (Uri url, {Map<String, String>? headers, Object? body}) async {
              postedUrl = url;
              return jsonResponse({"addedCount": 4}, 201);
            },
      ),
    );
    await tester.pumpAndSettle();

    await scrollToText(tester, "Huzurlu Akşamlar");

    expect(find.text("Huzurlu Akşamlar"), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsWidgets);

    await tester.tap(find.byIcon(Icons.check_rounded).last);
    await tester.pumpAndSettle();

    expect(postedUrl, isNull);
  });

  testWidgets("shows backend error state when templates cannot be loaded", (
    tester,
  ) async {
    await tester.pumpWidget(
      buildDiscoveryScreen(
        httpGet: (Uri url, {Map<String, String>? headers}) async {
          return jsonResponse({"message": "error"}, 500);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Şablonlar alınamadı."), findsOneWidget);
    expect(find.text("Tekrar dene"), findsOneWidget);
  });
}
