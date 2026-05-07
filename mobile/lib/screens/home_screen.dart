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
  bool isCompleted;

  HabitItem({
    required this.id,
    required this.title,
    this.description,
    required this.period,
    required this.days,
    this.isCompleted = false,
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
        .map((e) => e as int)
        .toList();

    return HabitItem(
      id: json["id"],
      title: json["name"] ?? "",
      description: json["description"],
      period: parsedPeriod,
      days: parsedDays,
      isCompleted: json["is_completed"] == true || json["is_completed"] == 1,
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

  @override
  void initState() {
    super.initState();
    fetchHabits();
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

  Future<void> toggleHabit(HabitItem habit) async {
    try {
      final accessToken = await TokenStorage.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Oturum bulunamadı.")));
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

  Color getBackgroundColor() {
    if (selectedFilter == HabitFilter.morning) {
      return const Color(0xFFEAF4FF);
    } else if (selectedFilter == HabitFilter.evening) {
      return const Color(0xFF1F2633);
    } else {
      return const Color(0xFFF7F7F7);
    }
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
    return Colors.white;
  }

  List<DateTime> getMonthDates(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);
    final totalDays = lastDayOfMonth.day;

    return List.generate(
      totalDays,
      (index) => DateTime(date.year, date.month, index + 1),
    );
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

  String formatMonthYear(DateTime date) {
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

    return "${months[date.month - 1]} ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = getBackgroundColor();
    final primaryTextColor = getPrimaryTextColor();
    final infoCardColor = getInfoCardColor();
    final monthDates = getMonthDates(selectedDate);

    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Home",
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatMonthYear(selectedDate),
                    style: TextStyle(
                      color: primaryTextColor.withOpacity(0.75),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: monthDates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final date = monthDates[index];
                  final isSelected =
                      date.day == selectedDate.day &&
                      date.month == selectedDate.month &&
                      date.year == selectedDate.year;

                  return GestureDetector(
                    onTap: () async {
                      setState(() {
                        selectedDate = date;
                        isLoading = true;
                      });
                      await fetchHabits();
                    },
                    child: Container(
                      width: 64,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue
                            : (selectedFilter == HabitFilter.evening
                                  ? const Color(0xFF2B3445)
                                  : Colors.white),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue
                              : Colors.grey.shade300,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekDayNames[date.weekday - 1],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : primaryTextColor.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${date.day}",
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : primaryTextColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
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
                      ? "Sabah filtresi seçili. Açık ve ferah bir görünüm gösteriliyor."
                      : selectedFilter == HabitFilter.evening
                      ? "Akşam filtresi seçili. Daha koyu bir tema gösteriliyor."
                      : "Tüm alışkanlıklar gösteriliyor.",
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

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: selectedFilter == HabitFilter.evening
                                ? const Color(0xFF2B3445)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.06),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: habit.isCompleted,
                                onChanged: (_) async {
                                  await toggleHabit(habit);
                                },
                                shape: const CircleBorder(),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      habit.title,
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        decoration: habit.isCompleted
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                    if (habit.description != null &&
                                        habit.description!
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        habit.description!,
                                        style: TextStyle(
                                          color: primaryTextColor.withOpacity(
                                            0.7,
                                          ),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                habit.isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: habit.isCompleted
                                    ? Colors.green
                                    : Colors.grey,
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
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
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
