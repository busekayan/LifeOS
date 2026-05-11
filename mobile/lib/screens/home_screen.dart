import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/token_storage.dart';
import 'add_habit_screen.dart';
import 'login_screen.dart';

enum HabitFilter { morning, all, evening }

class HabitItem {
  final int id;
  final String title;
  final String? description;
  final HabitFilter period;
  final List<int> days;
  final int? targetValue;
  final String? goalType;
  bool isCompleted;
  int currentValue;

  HabitItem({
    required this.id,
    required this.title,
    this.description,
    required this.period,
    required this.days,
    this.targetValue,
    this.goalType,
    this.isCompleted = false,
    this.currentValue = 0,
  });

  factory HabitItem.fromJson(Map<String, dynamic> json) {
    HabitFilter parsedPeriod;

    switch (json["period"]) {
      case "morning":
        parsedPeriod = HabitFilter.morning;
        break;
      case "evening":
        parsedPeriod = HabitFilter.evening;
        break;
      default:
        parsedPeriod = HabitFilter.all;
    }

    final List<int> parsedDays = (json["days"] as List<dynamic>? ?? [])
        .whereType<int>()
        .toList();

    return HabitItem(
      id: json["id"] as int,
      title: json["name"] ?? "",
      description: json["description"],
      period: parsedPeriod,
      days: parsedDays,
      targetValue: json["target_value"] as int?,
      goalType: json["goal_type"] as String?,
      isCompleted: json["is_completed"] == true || json["is_completed"] == 1,
      currentValue: json["current_value"] ?? 0 as int,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime selectedDate = DateTime.now();
  late final PageController calendarController;
  static const int calendarInitialPage = 10000;

  HabitFilter selectedFilter = HabitFilter.all;
  int selectedBottomNavIndex = 0;

  List<HabitItem> allHabits = [];
  bool isLoading = true;

  final List<String> weekDayNames = [
    "Pzt",
    "Sal",
    "Çar",
    "Per",
    "Cum",
    "Cmt",
    "Paz",
  ];

  @override
  void initState() {
    super.initState();

    calendarController = PageController(
      initialPage: calendarInitialPage,
      viewportFraction: 0.22,
    );

    fetchHabits();
  }

  @override
  void dispose() {
    calendarController.dispose();
    super.dispose();
  }

  String formatDateForApi(DateTime date) {
    return date.toIso8601String().split("T")[0];
  }

  List<HabitItem> get filteredHabits {
    final int selectedWeekDay = selectedDate.weekday;

    return allHabits.where((habit) {
      final bool matchesFilter =
          selectedFilter == HabitFilter.all || habit.period == selectedFilter;

      final bool matchesDay = habit.days.contains(selectedWeekDay);

      return matchesFilter && matchesDay;
    }).toList();
  }

  Future<void> fetchHabits() async {
    try {
      final accessToken = await TokenStorage.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Oturum açma bilgileri bulunamadı.")),
        );
        return;
      }

      final response = await http.get(
        Uri.parse(
          "http://localhost:3000/habits?date=${formatDateForApi(selectedDate)}",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> habitsJson = data["habits"] ?? [];

        setState(() {
          allHabits = habitsJson
              .map((json) => HabitItem.fromJson(json))
              .toList();
          isLoading = false;
        });
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Alışkanlıklar alınamadı.")));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sunucu bağlantısı kurulamadı.")),
      );
    }
  }

Future<void> handleHabitTap(HabitItem habit) async {
  if (!hasGoal(habit)) {
    await toggleHabit(habit);
    return;
  }
  await showGoalProgressSheet(habit);
}

Future<void> toggleHabit(HabitItem habit) async {
  try {
    final accessToken = await TokenStorage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Oturum bulunamadı.")),
      );
      return;
    }

    final response = await http.post(
      Uri.parse("http://localhost:3000/habit-logs/toggle"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode({
        "habit_id": habit.id,
        "log_date": formatDateForApi(selectedDate),
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      setState(() {
        habit.isCompleted = data["completed"] == true;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Alışkanlık durumu güncellenemedi.")),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sunucu bağlantısı kurulamadı.")),
    );
  }
}
Future<void> showGoalProgressSheet(HabitItem habit) async {
  final TextEditingController controller = TextEditingController(
    text: habit.currentValue > 0 ? habit.currentValue.toString() : "",
  );
  final String unit = getGoalUnitText(habit.goalType);
  final Color accentColor = getHabitAccentColor(habit);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFCFA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                habit.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Hedef: ${habit.targetValue} $unit",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.45),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Input
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Bugün ne kadar yaptın?",
                  suffixText: unit,
                  suffixStyle: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: accentColor.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: accentColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Kaydet butonu
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final int? value = int.tryParse(controller.text.trim());

                    if (value == null || value < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Geçerli bir değer gir.")),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    await updateHabitValue(habit, value);
                  },
                  child: const Text(
                    "Kaydet",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
Future<void> updateHabitValue(HabitItem habit, int value) async {
  try {
    final accessToken = await TokenStorage.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) return;

    final response = await http.patch(
      Uri.parse("http://localhost:3000/habit-logs/value"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode({
        "habit_id": habit.id,
        "log_date": formatDateForApi(selectedDate),
        "value": value,
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      setState(() {
        habit.currentValue = value;
        habit.isCompleted = data["completed"] == true;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("İlerleme güncellenemedi.")),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sunucu bağlantısı kurulamadı.")),
    );
  }
}

  Color getBackgroundColor() {
    if (selectedFilter == HabitFilter.evening) {
      return const Color(0xFF1F2633);
    }

    return const Color(0xFFF6F2FF);
  }

  Color getPrimaryTextColor() {
    if (selectedFilter == HabitFilter.evening) {
      return Colors.white;
    }

    return Colors.black;
  }

  Color getInfoCardColor() {
    if (selectedFilter == HabitFilter.evening) {
      return const Color(0xFF2B3445);
    }

    return const Color(0xFFFFFCFA);
  }

  String getFilterTitle() {
    switch (selectedFilter) {
      case HabitFilter.morning:
        return "Sabah alışkanlıkları";
      case HabitFilter.all:
        return "Tüm alışkanlıklar";
      case HabitFilter.evening:
        return "Akşam alışkanlıkları";
    }
  }

  DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  DateTime getDateFromPageIndex(int index) {
    final today = normalizeDate(DateTime.now());
    final difference = index - calendarInitialPage;

    return today.add(Duration(days: difference));
  }

  String formatCalendarLabel(DateTime date) {
    final today = normalizeDate(DateTime.now());
    final targetDate = normalizeDate(date);
    final difference = targetDate.difference(today).inDays;

    if (difference == 0) return "Bugün";
    if (difference == -1) return "Dün";
    if (difference == 1) return "Yarın";

    const months = [
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

    return "${date.day} ${months[date.month - 1]}";
  }

  Color getHabitAccentColor(HabitItem habit) {
    switch (habit.period) {
      case HabitFilter.morning:
        return const Color(0xFF8DB4FF);
      case HabitFilter.evening:
        return const Color(0xFFA78BFA);
      case HabitFilter.all:
        return const Color(0xFFFFB86B);
    }
  }

  IconData getHabitIcon(HabitItem habit) {
    switch (habit.period) {
      case HabitFilter.morning:
        return Icons.wb_sunny_rounded;
      case HabitFilter.evening:
        return Icons.nightlight_round;
      case HabitFilter.all:
        return Icons.auto_awesome_rounded;
    }
  }

  bool hasGoal(HabitItem habit) {
    return habit.targetValue != null &&
        habit.targetValue! > 0 &&
        habit.goalType != null &&
        habit.goalType!.trim().isNotEmpty;
  }

  String getGoalUnitText(String? goalType) {
    switch (goalType) {
      case "minute":
        return "dk";
      case "hour":
        return "saat";
      case "step":
        return "adım";
      case "liter":
        return "L";
      case "count":
        return "tekrar";
      default:
        return "";
    }
  }

  String getHabitProgressText(HabitItem habit) {
    if (!hasGoal(habit)) {
      return habit.isCompleted ? "Tamamlandı" : "Bugün için bekliyor";
    }


    final String unit = getGoalUnitText(habit.goalType);
    return "${habit.currentValue} / ${habit.targetValue} $unit"; // currentValue kullan

  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = getBackgroundColor();
    final primaryTextColor = getPrimaryTextColor();
    final infoCardColor = getInfoCardColor();

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddHabitScreen()),
          );

          if (result == true) {
            setState(() {
              isLoading = true;
            });
            await fetchHabits();
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedBottomNavIndex,
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 5) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            return;
          }

          setState(() {
            selectedBottomNavIndex = index;
          });

          if (index != 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Bu sayfa henüz eklenmedi.")),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: "Keşfet",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: "Araçlar",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: "Günlük",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: "Bütçe",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profil",
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  formatCalendarLabel(selectedDate),
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            SizedBox(
              height: 118,
              child: PageView.builder(
                controller: calendarController,
                itemCount: calendarInitialPage * 2,
                onPageChanged: (index) async {
                  final newDate = getDateFromPageIndex(index);

                  setState(() {
                    selectedDate = newDate;
                    isLoading = true;
                  });

                  await fetchHabits();
                },
                itemBuilder: (context, index) {
                  final date = getDateFromPageIndex(index);
                  final today = normalizeDate(DateTime.now());

                  final bool isSelected = isSameDate(date, selectedDate);
                  final bool isToday = isSameDate(date, today);

                  final Color selectedColor = const Color(0xFF6C63FF);
                  final Color todayBorderColor = const Color(0xFFFFB86B);
                  final Color cardColor = selectedFilter == HabitFilter.evening
                      ? const Color(0xFF2B3445)
                      : const Color(0xFFFFFBF5);

                  return GestureDetector(
                    onTap: () async {
                      await calendarController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: isSelected ? 4 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? selectedColor : cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? selectedColor
                              : isToday
                              ? todayBorderColor
                              : Colors.black.withOpacity(0.06),
                          width: isToday && !isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? selectedColor.withOpacity(0.25)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: isSelected ? 14 : 8,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 6,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekDayNames[date.weekday - 1],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.85)
                                  : primaryTextColor.withOpacity(0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${date.day}",
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : primaryTextColor,
                              fontSize: isSelected ? 24 : 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: infoCardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  selectedFilter == HabitFilter.morning
                      ? "Sabah filtresi seçili. Güne başlamak için planlanan alışkanlıklar gösteriliyor."
                      : selectedFilter == HabitFilter.evening
                      ? "Akşam filtresi seçili. Günü kapatırken takip edilecek alışkanlıklar gösteriliyor."
                      : "Bugün için planlanan tüm alışkanlıklar gösteriliyor.",
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: buildFilterButton(
                      title: "Sabah",
                      filter: HabitFilter.morning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildFilterButton(
                      title: "Tümü",
                      filter: HabitFilter.all,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: buildFilterButton(
                      title: "Akşam",
                      filter: HabitFilter.evening,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    getFilterTitle(),
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredHabits.isEmpty
                  ? Center(
                      child: Text(
                        "Bu gün ve filtre için henüz alışkanlık yok.",
                        style: TextStyle(
                          color: primaryTextColor.withOpacity(0.75),
                          fontSize: 15,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: filteredHabits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final habit = filteredHabits[index];
                        final Color accentColor = getHabitAccentColor(habit);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedFilter == HabitFilter.evening
                                ? const Color(0xFF2B3445)
                                : const Color(0xFFFFFCFA),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: habit.isCompleted
                                  ? accentColor.withOpacity(0.55)
                                  : Colors.black.withOpacity(0.05),
                              width: habit.isCompleted ? 1.4 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: habit.isCompleted
                                    ? accentColor.withOpacity(0.20)
                                    : Colors.black.withOpacity(0.05),
                                blurRadius: habit.isCompleted ? 16 : 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  getHabitIcon(habit),
                                  color: accentColor,
                                  size: 26,
                                ),
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      habit.title,
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        decoration: habit.isCompleted
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),

                                    if (habit.description != null &&
                                        habit.description!
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        habit.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: primaryTextColor.withOpacity(
                                            0.55,
                                          ),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 8),

                                    Row(
                                      children: [
                                        Icon(
                                          hasGoal(habit)
                                              ? Icons.track_changes_rounded
                                              : habit.isCompleted
                                              ? Icons.check_circle_rounded
                                              : Icons.hourglass_bottom_rounded,
                                          size: 14,
                                          color: habit.isCompleted
                                              ? accentColor
                                              : primaryTextColor.withOpacity(
                                                  0.45,
                                                ),
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            getHabitProgressText(habit),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: habit.isCompleted
                                                  ? accentColor
                                                  : primaryTextColor.withOpacity(
                                                      0.45,
                                                    ),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              GestureDetector(
                                onTap: () async {
                                  await handleHabitTap(habit);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: habit.isCompleted
                                        ? accentColor
                                        : accentColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    habit.isCompleted
                                        ? Icons.check_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: habit.isCompleted
                                        ? Colors.white
                                        : accentColor.withOpacity(0.85),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFilterButton({
    required String title,
    required HabitFilter filter,
  }) {
    final bool isSelected = selectedFilter == filter;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = filter;
        });
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFFFFFCFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6C63FF)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}