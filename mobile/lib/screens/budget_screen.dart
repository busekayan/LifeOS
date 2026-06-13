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

class BudgetSummary {
  final double incomeTotal;
  final double expenseTotal;
  final double sharedExpenseTotal;
  final double remainingBalance;

  const BudgetSummary({
    required this.incomeTotal,
    required this.expenseTotal,
    required this.sharedExpenseTotal,
    required this.remainingBalance,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    double parseAmount(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? "") ?? 0;
    }

    return BudgetSummary(
      incomeTotal: parseAmount(json["income_total"]),
      expenseTotal: parseAmount(json["expense_total"]),
      sharedExpenseTotal: parseAmount(json["shared_expense_total"]),
      remainingBalance: parseAmount(json["remaining_balance"]),
    );
  }
}

class BudgetTransaction {
  final int id;
  final String type;
  final String title;
  final double amount;
  final String transactionDate;
  final String? note;

  const BudgetTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.transactionDate,
    this.note,
  });

  factory BudgetTransaction.fromJson(Map<String, dynamic> json) {
    final amountValue = json["amount"];

    return BudgetTransaction(
      id: json["id"] as int,
      type: json["type"]?.toString() ?? "expense",
      title: json["title"]?.toString() ?? "",
      amount: amountValue is num
          ? amountValue.toDouble()
          : double.tryParse(amountValue?.toString() ?? "") ?? 0,
      transactionDate:
          json["transaction_date"]?.toString().split("T").first ?? "",
      note: json["note"]?.toString(),
    );
  }

  bool get isIncome => type == "income";
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
  BudgetSummary summary = const BudgetSummary(
    incomeTotal: 0,
    expenseTotal: 0,
    sharedExpenseTotal: 0,
    remainingBalance: 0,
  );
  List<BudgetTransaction> transactions = [];

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
      final transactionsResponse = await widget.httpGet(
        ApiConfig.uri("/budget/transactions", {"month": currentMonthKey()}),
        headers: headers,
      );

      if (!mounted) return;

      if (friendsResponse.statusCode != 200 ||
          groupsResponse.statusCode != 200 ||
          transactionsResponse.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorMessage = "Bütçe bilgileri alınamadı.";
        });
        return;
      }

      final friendsData = jsonDecode(friendsResponse.body);
      final groupsData = jsonDecode(groupsResponse.body);
      final transactionsData = jsonDecode(transactionsResponse.body);

      setState(() {
        friends = (friendsData["friends"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BudgetFriend.fromJson)
            .toList();
        groups = (groupsData["groups"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BudgetGroup.fromJson)
            .toList();
        summary = BudgetSummary.fromJson(
          transactionsData["summary"] as Map<String, dynamic>? ?? {},
        );
        transactions =
            (transactionsData["transactions"] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(BudgetTransaction.fromJson)
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

  String currentMonthKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, "0")}";
  }

  String currentDateKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}";
  }

  String formatCurrency(double amount) {
    final rounded = amount.round();
    return "$rounded TL";
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

  Future<void> showCreateTransactionDialog(String initialType) async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final dateController = TextEditingController(text: currentDateKey());
    final noteController = TextEditingController();
    String selectedType = initialType;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                selectedType == "income" ? "Gelir ekle" : "Gider ekle",
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: "income", label: Text("Gelir")),
                        ButtonSegment(value: "expense", label: Text("Gider")),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (value) {
                        setDialogState(() {
                          selectedType = value.first;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Başlık"),
                    ),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Tutar"),
                    ),
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: "Tarih",
                        hintText: "YYYY-AA-GG",
                      ),
                    ),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: "Not",
                        hintText: "Opsiyonel",
                      ),
                    ),
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
                    final amount = double.tryParse(
                      amountController.text.trim(),
                    );
                    final hasValidDate = RegExp(
                      r"^\d{4}-\d{2}-\d{2}$",
                    ).hasMatch(dateController.text.trim());

                    if (titleController.text.trim().isEmpty ||
                        amount == null ||
                        amount <= 0 ||
                        !hasValidDate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("İşlem bilgilerini kontrol et."),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, true);
                  },
                  child: const Text("Kaydet"),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted == true) {
      await createTransaction(
        type: selectedType,
        title: titleController.text.trim(),
        amount: double.parse(amountController.text.trim()),
        transactionDate: dateController.text.trim(),
        note: noteController.text.trim(),
      );
    }
  }

  Future<void> createTransaction({
    required String type,
    required String title,
    required double amount,
    required String transactionDate,
    required String note,
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
        ApiConfig.uri("/budget/transactions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode({
          "type": type,
          "title": title,
          "amount": amount,
          "transaction_date": transactionDate,
          "note": note.isEmpty ? null : note,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final transaction = BudgetTransaction.fromJson(
          data["transaction"] as Map<String, dynamic>,
        );

        setState(() {
          transactions.insert(0, transaction);
          final incomeTotal =
              summary.incomeTotal +
              (transaction.isIncome ? transaction.amount : 0);
          final expenseTotal =
              summary.expenseTotal +
              (transaction.isIncome ? 0 : transaction.amount);
          summary = BudgetSummary(
            incomeTotal: incomeTotal,
            expenseTotal: expenseTotal,
            sharedExpenseTotal: summary.sharedExpenseTotal,
            remainingBalance:
                incomeTotal - expenseTotal - summary.sharedExpenseTotal,
          );
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("İşlem eklendi.")));
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("İşlem eklenemedi.")));
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Kalan Bütçe",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatCurrency(summary.remainingBalance),
                style: const TextStyle(
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
                amount: formatCurrency(summary.incomeTotal),
                color: const Color(0xFF26A69A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildSummaryMetric(
                title: "Kişisel Gider",
                amount: formatCurrency(summary.expenseTotal),
                color: const Color(0xFFE57373),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        buildSummaryMetric(
          title: "Ortak Gider Payın",
          amount: formatCurrency(summary.sharedExpenseTotal),
          color: const Color(0xFFFFB86B),
          fullWidth: true,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: buildTransactionButton(
                label: "Gelir Ekle",
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF26A69A),
                onTap: () => showCreateTransactionDialog("income"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: buildTransactionButton(
                label: "Gider Ekle",
                icon: Icons.trending_down_rounded,
                color: const Color(0xFFE57373),
                onTap: () => showCreateTransactionDialog("expense"),
              ),
            ),
          ],
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
                "Son İşlemler",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (transactions.isEmpty)
                Text(
                  "Bu ay henüz gelir veya gider eklenmedi.",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                ...transactions.map(buildTransactionRow),
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

  Widget buildTransactionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTransactionRow(BudgetTransaction transaction) {
    final color = transaction.isIncome
        ? const Color(0xFF26A69A)
        : const Color(0xFFE57373);
    final prefix = transaction.isIncome ? "+" : "-";

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.note == null || transaction.note!.trim().isEmpty
                      ? transaction.transactionDate
                      : "${transaction.transactionDate} • ${transaction.note}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.48),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "$prefix${formatCurrency(transaction.amount)}",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
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
