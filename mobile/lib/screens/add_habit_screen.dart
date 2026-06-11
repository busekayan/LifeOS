import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_storage.dart';

typedef HttpPost =
    Future<http.Response> Function(
      Uri url, {
      Map<String, String>? headers,
      Object? body,
    });

typedef GetAccessToken = Future<String?> Function();

enum HabitTimePeriod { morning, all, evening }

enum HabitGoalType { none, minute, hour, step, liter, count }

class AddHabitScreen extends StatefulWidget {
  final HttpPost httpPost;
  final GetAccessToken getAccessToken;
  final bool popOnSuccess;

  const AddHabitScreen({
    super.key,
    this.httpPost = http.post,
    this.getAccessToken = TokenStorage.getAccessToken,
    this.popOnSuccess = true,
  });

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController targetValueController = TextEditingController();

  HabitTimePeriod selectedPeriod = HabitTimePeriod.morning;
  HabitGoalType selectedGoalType = HabitGoalType.none;

  final List<String> weekDays = const [
    "Pzt",
    "Sal",
    "Çar",
    "Per",
    "Cum",
    "Cmt",
    "Paz",
  ];

  final Set<String> selectedDays = {"Pzt", "Sal", "Çar", "Per", "Cum"};

  bool isLoading = false;

  String getPeriodText(HabitTimePeriod period) {
    switch (period) {
      case HabitTimePeriod.morning:
        return "Sabah";
      case HabitTimePeriod.all:
        return "Genel";
      case HabitTimePeriod.evening:
        return "Akşam";
    }
  }

  String getPeriodSubtitle(HabitTimePeriod period) {
    switch (period) {
      case HabitTimePeriod.morning:
        return "Güne başlarken";
      case HabitTimePeriod.all:
        return "Gün içinde";
      case HabitTimePeriod.evening:
        return "Günü kapatırken";
    }
  }

  String getGoalTypeText(HabitGoalType type) {
    switch (type) {
      case HabitGoalType.none:
        return "Hedef yok";
      case HabitGoalType.minute:
        return "Dakika";
      case HabitGoalType.hour:
        return "Saat";
      case HabitGoalType.step:
        return "Adım";
      case HabitGoalType.liter:
        return "Litre";
      case HabitGoalType.count:
        return "Tekrar";
    }
  }

  Future<void> saveHabit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("En az bir gün seçmelisin.")),
      );
      return;
    }

    final accessToken = await widget.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Oturum bulunamadı. Lütfen tekrar giriş yap."),
        ),
      );
      return;
    }

    final Map<String, int> dayMap = {
      "Pzt": 1,
      "Sal": 2,
      "Çar": 3,
      "Per": 4,
      "Cum": 5,
      "Cmt": 6,
      "Paz": 7,
    };

    final List<int> daysAsInt = selectedDays.map((day) => dayMap[day]!).toList()
      ..sort();

    final int? targetValue = selectedGoalType == HabitGoalType.none
        ? null
        : int.tryParse(targetValueController.text.trim());

    final Map<String, dynamic> body = {
      "name": nameController.text.trim(),
      "description": descriptionController.text.trim(),
      "period": selectedPeriod.name,
      "frequency_type": "weekly",
      "days": daysAsInt,
      "target_value": targetValue,
      "goal_type": selectedGoalType == HabitGoalType.none
          ? null
          : selectedGoalType.name,
    };

    setState(() {
      isLoading = true;
    });

    try {
      print("ADD HABIT TOKEN: $accessToken");
      print("ADD HABIT BODY: ${jsonEncode(body)}");

      final response = await widget.httpPost(
        ApiConfig.uri("/habits"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode(body),
      );

      print("ADD HABIT STATUS: ${response.statusCode}");
      print("ADD HABIT RESPONSE: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alışkanlık başarıyla eklendi.")),
        );
        if (widget.popOnSuccess) {
          Navigator.pop(context, true);
        }
        return;
      }

      try {
        final data = jsonDecode(response.body);
        final message = data["message"] ?? "Alışkanlık eklenemedi.";
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      } catch (_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Alışkanlık eklenemedi.")));
      }
    } catch (e) {
      print("ADD HABIT ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sunucu bağlantısı kurulamadı.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    targetValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2FF),
      appBar: AppBar(
        title: const Text("Yeni Alışkanlık"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF6F2FF),
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                buildHeroCard(),
                const SizedBox(height: 16),
                buildGeneralInfoCard(),
                const SizedBox(height: 16),
                buildPeriodCard(),
                const SizedBox(height: 16),
                buildGoalCard(),
                const SizedBox(height: 16),
                buildDaysCard(),
                const SizedBox(height: 24),
                buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFFFF8FA3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Yeni bir alışkanlık oluştur",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Başlık, zaman dilimi, hedef ve tekrar günlerini seç. Kaydettikten sonra ana ekrandan takip edebileceksin.",
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget buildGeneralInfoCard() {
    return buildSectionCard(
      title: "Genel Bilgiler",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Alışkanlık Adı",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: customInputDecoration(
              hintText: "Örn: Günde 2 litre su iç",
            ),
            validator: (value) {
              final text = value?.trim() ?? "";

              if (text.isEmpty) {
                return "Alışkanlık adı zorunludur";
              }

              if (text.length < 3) {
                return "En az 3 karakter olmalı";
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            "Açıklama",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: descriptionController,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: customInputDecoration(
              hintText: "İstersen kısa bir açıklama ekleyebilirsin",
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPeriodCard() {
    return buildSectionCard(
      title: "Zaman Dilimi",
      child: Column(
        children: HabitTimePeriod.values.map((period) {
          final bool isSelected = selectedPeriod == period;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedPeriod = period;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEDEBFF)
                    : const Color(0xFFFFFCFA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6C63FF)
                      : Colors.black.withOpacity(0.08),
                  width: isSelected ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: Icon(
                      getPeriodIcon(period),
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          getPeriodText(period),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF4D46CC)
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          getPeriodSubtitle(period),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? const Color(0xFF6C63FF) : Colors.grey,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget buildGoalCard() {
    return buildSectionCard(
      title: "Ölçülebilir Hedef",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "İstersen bu alışkanlık için dakika, adım, litre veya tekrar gibi basit bir hedef ekleyebilirsin.",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.62),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: HabitGoalType.values.map((type) {
              final bool isSelected = selectedGoalType == type;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedGoalType = type;

                    if (type == HabitGoalType.none) {
                      targetValueController.clear();
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : const Color(0xFFFFFCFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.black.withOpacity(0.08),
                    ),
                  ),
                  child: Text(
                    getGoalTypeText(type),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (selectedGoalType != HabitGoalType.none) ...[
            const SizedBox(height: 16),
            const Text(
              "Hedef Değeri",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: targetValueController,
              keyboardType: TextInputType.number,
              decoration: customInputDecoration(hintText: "Örn: 20, 8000, 2"),
              validator: (value) {
                if (selectedGoalType == HabitGoalType.none) {
                  return null;
                }

                final text = value?.trim() ?? "";

                if (text.isEmpty) {
                  return "Hedef değeri zorunludur";
                }

                final number = int.tryParse(text);

                if (number == null || number <= 0) {
                  return "Geçerli bir sayı gir";
                }

                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget buildDaysCard() {
    return buildSectionCard(
      title: "Tekrar Günleri",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bu alışkanlığın hangi günlerde aktif olacağını seç.",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.62),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: weekDays.map((day) {
              final bool isSelected = selectedDays.contains(day);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedDays.remove(day);
                    } else {
                      selectedDays.add(day);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : const Color(0xFFFFFCFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.black.withOpacity(0.08),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.14),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    day,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : saveHabit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          disabledBackgroundColor: const Color(0xFFBDB7FF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Text(
                "Alışkanlığı Kaydet",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCFA),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration customInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.black.withOpacity(0.45),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F4FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  IconData getPeriodIcon(HabitTimePeriod period) {
    switch (period) {
      case HabitTimePeriod.morning:
        return Icons.wb_sunny_rounded;
      case HabitTimePeriod.all:
        return Icons.schedule_rounded;
      case HabitTimePeriod.evening:
        return Icons.nights_stay_rounded;
    }
  }
}
