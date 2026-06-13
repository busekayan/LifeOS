import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_storage.dart';
import '../widgets/app_bottom_navigation_bar.dart';

typedef HttpGet =
    Future<http.Response> Function(Uri url, {Map<String, String>? headers});

typedef HttpPost =
    Future<http.Response> Function(
      Uri url, {
      Map<String, String>? headers,
      Object? body,
    });

typedef GetAccessToken = Future<String?> Function();

class BudgetFriend {
  final int id;
  final String firstName;
  final String lastName;
  final String email;

  const BudgetFriend({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory BudgetFriend.fromJson(Map<String, dynamic> json) {
    return BudgetFriend(
      id: json["id"] as int,
      firstName: json["first_name"]?.toString() ?? "",
      lastName: json["last_name"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
    );
  }

  String get displayName {
    final name = "$firstName $lastName".trim();
    return name.isEmpty ? email : name;
  }
}

class BudgetGroup {
  final int id;
  final String name;
  final List<BudgetFriend> members;

  const BudgetGroup({
    required this.id,
    required this.name,
    required this.members,
  });

  factory BudgetGroup.fromJson(Map<String, dynamic> json) {
    final membersJson = json["members"] as List<dynamic>? ?? [];

    return BudgetGroup(
      id: json["id"] as int,
      name: json["name"]?.toString() ?? "",
      members: membersJson
          .whereType<Map<String, dynamic>>()
          .map(BudgetFriend.fromJson)
          .toList(),
    );
  }
}

class BudgetScreen extends StatefulWidget {
  final HttpGet httpGet;
  final HttpPost httpPost;
  final GetAccessToken getAccessToken;

  const BudgetScreen({
    super.key,
    this.httpGet = http.get,
    this.httpPost = http.post,
    this.getAccessToken = TokenStorage.getAccessToken,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool isLoading = true;
  String? errorMessage;
  int selectedTab = 0;

  List<BudgetFriend> friends = [];
  List<BudgetGroup> groups = [];

  @override
  void initState() {
    super.initState();
    fetchBudgetData();
  }

  Future<void> fetchBudgetData() async {
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

      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      };

      final friendsResponse = await widget.httpGet(
        ApiConfig.uri("/budget/friends"),
        headers: headers,
      );
      final groupsResponse = await widget.httpGet(
        ApiConfig.uri("/budget/groups"),
        headers: headers,
      );

      if (!mounted) return;

      if (friendsResponse.statusCode != 200 ||
          groupsResponse.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorMessage = "Bütçe bilgileri alınamadı.";
        });
        return;
      }

      final friendsData = jsonDecode(friendsResponse.body);
      final groupsData = jsonDecode(groupsResponse.body);

      setState(() {
        friends = (friendsData["friends"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BudgetFriend.fromJson)
            .toList();
        groups = (groupsData["groups"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BudgetGroup.fromJson)
            .toList();
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = "Sunucu bağlantısı kurulamadı.";
      });
    }
  }

  Future<void> showCreateGroupDialog() async {
    if (friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Grup oluşturmak için önce arkadaş eklemelisin."),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final selectedFriendIds = <int>{};

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Ortak grup oluştur"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Grup adı",
                        hintText: "Ev Arkadaşları",
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Arkadaşlar",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...friends.map((friend) {
                      final isSelected = selectedFriendIds.contains(friend.id);
                      return CheckboxListTile(
                        value: isSelected,
                        contentPadding: EdgeInsets.zero,
                        title: Text(friend.displayName),
                        subtitle: Text(friend.email),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedFriendIds.add(friend.id);
                            } else {
                              selectedFriendIds.remove(friend.id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Vazgeç"),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty ||
                        selectedFriendIds.isEmpty) {
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text("Oluştur"),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
      await createGroup(
        name: nameController.text.trim(),
        memberIds: selectedFriendIds.toList(),
      );
    }
  }

  Future<void> createGroup({
    required String name,
    required List<int> memberIds,
  }) async {
    try {
      final accessToken = await widget.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Oturum bulunamadı.")));
        return;
      }

      final response = await widget.httpPost(
        ApiConfig.uri("/budget/groups"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode({"name": name, "memberIds": memberIds}),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          groups.insert(
            0,
            BudgetGroup.fromJson(data["group"] as Map<String, dynamic>),
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ortak bütçe grubu oluşturuldu.")),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ortak bütçe grubu oluşturulamadı.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sunucu bağlantısı kurulamadı.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2FF),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 3),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bütçe",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              buildTabs(),
              const SizedBox(height: 18),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? buildErrorState()
                    : selectedTab == 0
                    ? buildPersonalTab()
                    : buildSharedTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTabs() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [buildTabButton("Kişisel", 0), buildTabButton("Ortak", 1)],
      ),
    );
  }

  Widget buildTabButton(String label, int index) {
    final isSelected = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w800,
            ),
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
            errorMessage ?? "Bütçe bilgileri alınamadı.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: fetchBudgetData,
            child: const Text("Tekrar dene"),
          ),
        ],
      ),
    );
  }

  Widget buildPersonalTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF222831),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Kalan Bütçe",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "0 TL",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: buildSummaryMetric(
                title: "Gelir",
                amount: "0 TL",
                color: const Color(0xFF26A69A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildSummaryMetric(
                title: "Kişisel Gider",
                amount: "0 TL",
                color: const Color(0xFFE57373),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        buildSummaryMetric(
          title: "Ortak Gider Payın",
          amount: "0 TL",
          color: const Color(0xFFFFB86B),
          fullWidth: true,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bu Ay",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                "Gelir, kişisel gider ve ortak gider payı bu alanda birlikte takip edilecek.",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildSummaryMetric({
    required String title,
    required String amount,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.black.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSharedTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (groups.isEmpty)
          buildSharedEmptyState()
        else ...[
          ...groups.map(buildGroupCard),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: showCreateGroupDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.group_add_rounded),
            label: const Text(
              "Grup Oluştur",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget buildSharedEmptyState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Color(0xFF6C63FF),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Henüz ortak bütçe grubu yok",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            "Kabul edilmiş arkadaşlarınla kira, market veya tatil giderlerini birlikte takip edebilirsin.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.55),
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGroupCard(BudgetGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.members.map((member) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  member.displayName,
                  style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
