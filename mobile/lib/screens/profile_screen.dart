import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_storage.dart';
import '../widgets/app_bottom_navigation_bar.dart';

typedef HttpGet =
    Future<http.Response> Function(Uri url, {Map<String, String>? headers});
typedef GetAccessToken = Future<String?> Function();
typedef ClearTokens = Future<void> Function();
typedef CurrentDate = DateTime Function();

const Map<String, String> moodLabels = {
  "mutlu": "Mutlu",
  "sakin": "Sakin",
  "enerjik": "Enerjik",
  "uzgun": "Üzgün",
  "stresli": "Stresli",
  "yorgun": "Yorgun",
};

const Map<String, Color> moodColors = {
  "mutlu": Color(0xFFFFC857),
  "sakin": Color(0xFF5BC0BE),
  "enerjik": Color(0xFFFF7A59),
  "uzgun": Color(0xFF6C8AE4),
  "stresli": Color(0xFFE76F9A),
  "yorgun": Color(0xFF8D99AE),
};

const List<String> weekdayLabels = [
  "Pzt",
  "Sal",
  "Çar",
  "Per",
  "Cum",
  "Cmt",
  "Paz",
];
const List<String> monthLabels = [
  "Ocak",
  "Şubat",
  "Mart",
  "Nisan",
  "Mayıs",
  "Haziran",
  "Temmuz",
  "Ağustos",
  "Eylül",
  "Ekim",
  "Kasım",
  "Aralık",
];

class ProfileUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;

  const ProfileUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    return ProfileUser(
      id: json["id"] as int? ?? 0,
      firstName: json["firstName"]?.toString() ?? "",
      lastName: json["lastName"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
    );
  }

  String get displayName {
    final name = "$firstName $lastName".trim();
    return name.isEmpty ? email : name;
  }
}

class MoodEntry {
  final String mood;
  final DateTime date;

  const MoodEntry({required this.mood, required this.date});

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      mood: json["mood"]?.toString() ?? "",
      date: DateTime.parse(json["log_date"].toString()),
    );
  }

  String get dateKey => formatDateKey(date);
  String get label => moodLabels[mood] ?? mood;
  Color get color => moodColors[mood] ?? const Color(0xFFB8B8C8);
}

class DiaryEntry {
  final int id;
  final String content;
  final DateTime date;

  const DiaryEntry({
    required this.id,
    required this.content,
    required this.date,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json["id"] as int? ?? 0,
      content: json["content"]?.toString() ?? "",
      date: DateTime.parse(json["date"].toString()),
    );
  }

  String get dateKey => formatDateKey(date);
  String get displayDate => "${date.day} ${monthLabels[date.month - 1]}";
}

class ProfileScreen extends StatefulWidget {
  final HttpGet httpGet;
  final GetAccessToken getAccessToken;
  final ClearTokens clearTokens;
  final CurrentDate currentDate;

  const ProfileScreen({
    super.key,
    this.httpGet = http.get,
    this.getAccessToken = TokenStorage.getAccessToken,
    this.clearTokens = TokenStorage.clearTokens,
    this.currentDate = DateTime.now,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  bool isMoodCalendarLoading = false;
  bool isDiaryLoading = false;
  String? errorMessage;
  String? moodCalendarError;
  String? diaryError;
  ProfileUser? user;
  DateTime viewedMonth = DateTime.now();
  Map<String, MoodEntry> monthlyMoods = {};
  MoodEntry? selectedMood;
  List<DiaryEntry> diaryEntries = [];
  final Set<int> expandedDiaryIds = {};

  @override
  void initState() {
    super.initState();
    final today = widget.currentDate();
    viewedMonth = DateTime(today.year, today.month);
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final accessToken = await widget.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorMessage = "Oturum bulunamadı.";
        });
        return;
      }

      final response = await widget.httpGet(
        ApiConfig.uri("/users/me"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorMessage = "Profil bilgileri alınamadı.";
        });
        return;
      }

      final data = jsonDecode(response.body);
      setState(() {
        user = ProfileUser.fromJson(
          data["user"] as Map<String, dynamic>? ?? {},
        );
        isLoading = false;
        errorMessage = null;
      });
      await Future.wait([
        fetchMonthlyMoods(accessToken),
        fetchDiaries(accessToken),
      ]);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = "Sunucu bağlantısı kurulamadı.";
      });
    }
  }

  Future<void> fetchDiaries(String accessToken) async {
    setState(() {
      isDiaryLoading = true;
      diaryError = null;
    });

    try {
      final response = await widget.httpGet(
        ApiConfig.uri("/diaries"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          isDiaryLoading = false;
          diaryError = "Günlük kayıtları yüklenemedi.";
        });
        return;
      }

      final data = jsonDecode(response.body);
      final list = data is List
          ? data
          : data["diaries"] as List<dynamic>? ?? [];
      final entries =
          list
              .whereType<Map<String, dynamic>>()
              .map(DiaryEntry.fromJson)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        diaryEntries = entries.take(4).toList();
        isDiaryLoading = false;
        diaryError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isDiaryLoading = false;
        diaryError = "Günlük kayıtları yüklenemedi.";
      });
    }
  }

  Future<void> fetchMonthlyMoods(String accessToken) async {
    setState(() {
      isMoodCalendarLoading = true;
      moodCalendarError = null;
      selectedMood = null;
    });

    try {
      final response = await widget.httpGet(
        ApiConfig.uri("/moods/month", {
          "year": viewedMonth.year.toString(),
          "month": viewedMonth.month.toString(),
        }),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          isMoodCalendarLoading = false;
          moodCalendarError = "Mood takvimi yüklenemedi.";
        });
        return;
      }

      final data = jsonDecode(response.body);
      final moods = (data["moods"] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MoodEntry.fromJson);

      setState(() {
        monthlyMoods = {for (final mood in moods) mood.dateKey: mood};
        isMoodCalendarLoading = false;
        moodCalendarError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isMoodCalendarLoading = false;
        moodCalendarError = "Mood takvimi yüklenemedi.";
      });
    }
  }

  Future<void> changeMonth(int offset) async {
    final accessToken = await widget.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      if (!mounted) return;
      setState(() {
        moodCalendarError = "Oturum bulunamadı.";
      });
      return;
    }

    setState(() {
      viewedMonth = DateTime(viewedMonth.year, viewedMonth.month + offset);
    });
    await fetchMonthlyMoods(accessToken);
  }

  Future<void> logout() async {
    await widget.clearTokens();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2FF),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Profil",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: logout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      "Çıkış Yap",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFC84C4C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? buildErrorState()
                    : buildProfileContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            errorMessage ?? "Profil bilgileri alınamadı.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: fetchProfile, child: const Text("Tekrar dene")),
        ],
      ),
    );
  }

  Widget buildProfileContent() {
    final currentUser = user;

    if (currentUser == null) {
      return buildErrorState();
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF222831),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  currentUser.displayName.isEmpty
                      ? "?"
                      : currentUser.displayName.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        buildMoodCalendar(),
        buildDiaryHistory(),
        buildProfilePlaceholder(
          icon: Icons.bar_chart_rounded,
          title: "Alışkanlık istatistikleri",
          description:
              "Tamamlama oranların ve haftalık ilerlemen burada olacak.",
        ),
      ],
    );
  }

  Widget buildMoodCalendar() {
    final daysInMonth = DateTime(
      viewedMonth.year,
      viewedMonth.month + 1,
      0,
    ).day;
    final firstWeekday = DateTime(
      viewedMonth.year,
      viewedMonth.month,
      1,
    ).weekday;
    final leadingEmptyDays = firstWeekday - 1;
    final totalCells = leadingEmptyDays + daysInMonth;
    final trailingEmptyDays = (7 - totalCells % 7) % 7;
    final today = widget.currentDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF5BC0BE).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF168A88),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mood takvimi",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "${monthLabels[viewedMonth.month - 1]} ${viewedMonth.year}",
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Önceki ay",
                onPressed: isMoodCalendarLoading ? null : () => changeMonth(-1),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: "Sonraki ay",
                onPressed: isMoodCalendarLoading ? null : () => changeMonth(1),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final calendarWidth = constraints.maxWidth < 252
                  ? constraints.maxWidth
                  : 252.0;

              return Center(
                child: SizedBox(
                  width: calendarWidth,
                  child: Column(
                    children: [
                      Row(
                        children: weekdayLabels
                            .map(
                              (label) => Expanded(
                                child: Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: Colors.black.withValues(
                                        alpha: 0.48,
                                      ),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                      if (isMoodCalendarLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1,
                          children: [
                            for (var i = 0; i < leadingEmptyDays; i++)
                              const SizedBox.shrink(),
                            for (var day = 1; day <= daysInMonth; day++)
                              buildMoodDay(
                                DateTime(
                                  viewedMonth.year,
                                  viewedMonth.month,
                                  day,
                                ),
                                today,
                              ),
                            for (var i = 0; i < trailingEmptyDays; i++)
                              const SizedBox.shrink(),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (!isMoodCalendarLoading) ...[
            const SizedBox(height: 10),
            if (moodCalendarError != null)
              Text(
                moodCalendarError!,
                style: const TextStyle(
                  color: Color(0xFFC84C4C),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              )
            else if (monthlyMoods.isEmpty)
              Text(
                "Bu ay için mood kaydı yok.",
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.52),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (selectedMood != null)
              buildMoodSummary(selectedMood!)
            else
              Text(
                "Renkli günlere dokunarak mood detayını görebilirsin.",
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.52),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget buildMoodDay(DateTime date, DateTime today) {
    final mood = monthlyMoods[formatDateKey(date)];
    final isToday = isSameDate(date, today);
    final isSelected = selectedMood?.dateKey == formatDateKey(date);
    final moodColor = mood?.color;

    return Semantics(
      button: mood != null,
      label: mood == null
          ? "${date.day}. gün mood kaydı yok"
          : "${date.day}. gün ${mood.label}",
      child: InkWell(
        key: ValueKey("mood-day-${formatDateKey(date)}"),
        borderRadius: BorderRadius.circular(12),
        onTap: mood == null
            ? null
            : () {
                setState(() {
                  selectedMood = mood;
                });
              },
        child: Container(
          decoration: BoxDecoration(
            color:
                moodColor?.withValues(alpha: 0.86) ?? const Color(0xFFF4F1FA),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF222831)
                  : isToday
                  ? const Color(0xFF6C63FF)
                  : Colors.transparent,
              width: isSelected ? 2 : 1.6,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            date.day.toString(),
            style: TextStyle(
              color: mood == null
                  ? Colors.black.withValues(alpha: 0.46)
                  : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMoodSummary(MoodEntry mood) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: mood.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: mood.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "${mood.date.day} ${monthLabels[mood.date.month - 1]}: ${mood.label}",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDiaryHistory() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF6C63FF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Günlük geçmişi",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isDiaryLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (diaryError != null)
            Text(
              diaryError!,
              style: const TextStyle(
                color: Color(0xFFC84C4C),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            )
          else if (diaryEntries.isEmpty)
            Text(
              "Henüz günlük kaydın yok. Yazdıkların burada görünecek.",
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.54),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < diaryEntries.length; index++) ...[
                  buildDiaryEntryTile(diaryEntries[index]),
                  if (index != diaryEntries.length - 1)
                    Divider(
                      height: 14,
                      color: Colors.black.withValues(alpha: 0.07),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget buildDiaryEntryTile(DiaryEntry entry) {
    final isExpanded = expandedDiaryIds.contains(entry.id);

    return InkWell(
      key: ValueKey("diary-entry-${entry.id}"),
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          if (isExpanded) {
            expandedDiaryIds.remove(entry.id);
          } else {
            expandedDiaryIds.add(entry.id);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              child: Text(
                entry.displayDate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.52),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.content.trim().isEmpty
                    ? "Boş günlük kaydı"
                    : entry.content,
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF222831),
                  fontSize: 12,
                  height: 1.32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Colors.black.withValues(alpha: 0.42),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProfilePlaceholder({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.52),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String formatDateKey(DateTime date) {
  return "${date.year.toString().padLeft(4, "0")}-"
      "${date.month.toString().padLeft(2, "0")}-"
      "${date.day.toString().padLeft(2, "0")}";
}

bool isSameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
