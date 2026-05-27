import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/token_storage.dart';
import 'home_screen.dart';

class MoodOption {
  final String key;
  final String label;
  final Color color;
  final IconData icon;

  const MoodOption({
    required this.key,
    required this.label,
    required this.color,
    required this.icon,
  });
}

class DailyQuestion {
  final int id;
  final String question;

  DailyQuestion({
    required this.id,
    required this.question,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> json) {
    return DailyQuestion(
      id: json["id"],
      question: json["question"],
    );
  }
}

const List<MoodOption> moodOptions = [
  MoodOption(
    key: "mutlu",
    label: "Mutlu",
    color: Color(0xFFFFD166),
    icon: Icons.sentiment_very_satisfied_rounded,
  ),
  MoodOption(
    key: "sakin",
    label: "Sakin",
    color: Color(0xFF8DB4FF),
    icon: Icons.self_improvement_rounded,
  ),
  MoodOption(
    key: "enerjik",
    label: "Enerjik",
    color: Color(0xFF6BCB77),
    icon: Icons.bolt_rounded,
  ),
  MoodOption(
    key: "uzgun",
    label: "Üzgün",
    color: Color(0xFF6EC6F5),
    icon: Icons.sentiment_dissatisfied_rounded,
  ),
  MoodOption(
    key: "stresli",
    label: "Stresli",
    color: Color(0xFFFF9A8B),
    icon: Icons.whatshot_rounded,
  ),
  MoodOption(
    key: "yorgun",
    label: "Yorgun",
    color: Color(0xFFB39DDB),
    icon: Icons.bedtime_rounded,
  ),
];

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  String? selectedMood;
  List<DailyQuestion> dailyQuestions = [];
  bool isLoading = true;

  Color currentColor = const Color(0xFFE8E0FF);
  double fillValue = 0;

  int selectedBottomNavIndex = 3;

  static const String baseUrl = "http://127.0.0.1:3000";

  final TextEditingController diaryController = TextEditingController();

  @override
  void dispose() {
  diaryController.dispose();
  super.dispose();
}


  String formatDateForApi(DateTime date) {
    return date.toIso8601String().split("T")[0];
  }

  MoodOption? get selectedMoodOption {
    if (selectedMood == null) return null;
    return moodOptions.firstWhere(
      (m) => m.key == selectedMood,
      orElse: () => moodOptions[0],
    );
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }
Future<void> loadData() async {
  setState(() => isLoading = true);

  await Future.wait([
    fetchMood(),
    fetchDailyQuestions(),
  ]);

  if (mounted) {
    setState(() => isLoading = false);
  }
}
  Future<void> fetchMood() async {
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse("$baseUrl/moods?date=${formatDateForApi(DateTime.now())}"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final mood = data["mood"];

        if (mood != null) {
          final option = moodOptions.firstWhere(
            (m) => m.key == mood,
            orElse: () => moodOptions[0],
          );

          setState(() {
            selectedMood = mood;
            currentColor = option.color;
            fillValue = 1;
          });
        }
      }
    } catch (_) {}

    
  }

  Future<void> fetchDailyQuestions() async {
  try {
    final token = await TokenStorage.getAccessToken();

    if (token == null) return;

    final response = await http.get(
      Uri.parse("$baseUrl/questions/daily-questions"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final List list = data is List ? data : data["questions"] ?? [];

      setState(() {
        dailyQuestions = list
            .map((e) => DailyQuestion.fromJson(e))
            .toList();
      });
    }
    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");
  } 
  
  catch (e) {
    print(e);
  }

  
}

  Future<void> saveMood(String mood) async {
    try {
      final token = await TokenStorage.getAccessToken();

      await http.post(
        Uri.parse("$baseUrl/moods"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "mood": mood,
          "log_date": formatDateForApi(DateTime.now()),
        }),
      );
    } catch (_) {}
  }
Future<void> saveDiary() async {
  try {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return;

    final response = await http.post(
      Uri.parse("$baseUrl/diaries"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "content": diaryController.text,
        "date": formatDateForApi(DateTime.now()),
      }),
    );

    print("DIARY SAVE: ${response.statusCode}");
    print("BODY: ${response.body}");
  } catch (e) {
    print("DIARY ERROR: $e");
  }
}
Future<void> fetchDiaries() async {
  final token = await TokenStorage.getAccessToken();

  final res = await http.get(
    Uri.parse("$baseUrl/diaries"),
    headers: {"Authorization": "Bearer $token"},
  );

  print(res.body);
}
  void selectMood(MoodOption option) {
    setState(() {
      selectedMood = option.key;
      currentColor = option.color;
      fillValue = 0;
    });

    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      setState(() => fillValue = 1);
    });

    saveMood(option.key);
  }

  Widget moodBubble(MoodOption option) {
    final selected = selectedMood == option.key;

    return GestureDetector(
      onTap: () => selectMood(option),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: selected ? 40 : 34,
            height: selected ? 40 : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: option.color,
              border: selected ? Border.all(color: Colors.white, width: 2) : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            option.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: option.color,
            ),
          )
        ],
      ),
    );
  }

  Widget buildGlassBall() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fillValue),
      duration: const Duration(milliseconds: 650),
      builder: (_, value, _) {
        return Container(
          width: 95,
          height: 95,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(.30),
            border: Border.all(color: Colors.white.withOpacity(.75), width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 650),
                width: 95 * value,
                height: 95 * value,
                decoration: BoxDecoration(
                  color: currentColor,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                selectedMoodOption?.icon ?? Icons.water_drop_rounded,
                size: 30,
                color: Colors.white,
              )
            ],
          ),
        );
      },
    );
    
  }
  Widget buildDiaryCard() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Günlük Not",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),

       TextField(
  controller: diaryController,
  maxLines: 8,
  minLines: 6,
  keyboardType: TextInputType.multiline,
  decoration: InputDecoration(
    hintText: "Bugün neler oldu? Nasıl hissediyorsun?",
    hintStyle: TextStyle(
      color: Colors.grey.shade500,
    ),
    filled: true,
    fillColor: const Color(0xFFF8F6FF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(
        color: Color(0xFF6C63FF),
        width: 1.5,
      ),
    ),
  ),
),
const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: saveDiary,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF6C63FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    child: const Text("Kaydet"),
  ),
),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final left = moodOptions.sublist(0, 3);
    final right = moodOptions.sublist(3, 6);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2FF),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedBottomNavIndex,
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
            if (index == selectedBottomNavIndex) return;

            setState(() => selectedBottomNavIndex = index);

            switch (index) {
            case 0:
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
             pageBuilder: (_, _, _) => const HomePage(),
               transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
  ),
);
                break;

              case 1:
               Navigator.pushReplacementNamed(context, "/explore");
              break;

              case 2:
                Navigator.pushReplacementNamed(context, "/tools");
                break;

              case 3:
      // zaten DailyScreenr
               break;

              case 4:
               Navigator.pushReplacementNamed(context, "/budget");
               break;

               case 5:
               Navigator.pushReplacementNamed(context, "/profile");
                break;
  }
},
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
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Günlük",
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 28),

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Bugün nasıl hissediyorsun?",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: left.map((e) => moodBubble(e)).toList(),
                                ),
                              ),
                              buildGlassBall(),
                              Expanded(
                                child: Column(
                                  children: right.map((e) => moodBubble(e)).toList(),
                                ),
                              ),
                            ],
                          ),

                          if (selectedMoodOption != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              "Bugün ${selectedMoodOption!.label.toLowerCase()} hissediyorsun",
                              style: TextStyle(
                                color: selectedMoodOption!.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    buildDiaryCard(),
                    const SizedBox(height: 24),

const Text(
  "Bugünün Soruları",
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  ),
),

const SizedBox(height: 14),

...dailyQuestions.map(
  (q) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 10,
        ),
      ],
    ),
    child: Text(
      q.question,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
),
                  ],
                ),
              ),
      ),
    );
  }
}