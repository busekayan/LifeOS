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

class FriendInvitation {
  final int id;
  final int requesterId;
  final String firstName;
  final String lastName;
  final String email;

  const FriendInvitation({
    required this.id,
    required this.requesterId,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory FriendInvitation.fromJson(Map<String, dynamic> json) {
    return FriendInvitation(
      id: json["id"] as int,
      requesterId: json["requester_id"] as int,
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
  final List<SharedExpense> expenses;
  final SettlementSummary? settlementSummary;

  const BudgetGroup({
    required this.id,
    required this.name,
    required this.members,
    this.expenses = const <SharedExpense>[],
    this.settlementSummary,
  });

  factory BudgetGroup.fromJson(Map<String, dynamic> json) {
    final membersJson = json["members"];
    final expensesJson = json["expenses"];
    final settlementSummaryJson = json["settlement_summary"];

    return BudgetGroup(
      id: json["id"] as int,
      name: json["name"]?.toString() ?? "",
      members: membersJson is List
          ? membersJson
                .whereType<Map<String, dynamic>>()
                .map(BudgetFriend.fromJson)
                .toList()
          : <BudgetFriend>[],
      expenses: expensesJson is List
          ? expensesJson
                .whereType<Map<String, dynamic>>()
                .map(SharedExpense.fromJson)
                .toList()
          : <SharedExpense>[],
      settlementSummary: settlementSummaryJson is Map<String, dynamic>
          ? SettlementSummary.fromJson(settlementSummaryJson)
          : null,
    );
  }
}

class SharedExpenseParticipant {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final double shareAmount;

  const SharedExpenseParticipant({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.shareAmount,
  });

  factory SharedExpenseParticipant.fromJson(Map<String, dynamic> json) {
    final shareValue = json["share_amount"];

    return SharedExpenseParticipant(
      id: json["id"] as int,
      firstName: json["first_name"]?.toString() ?? "",
      lastName: json["last_name"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      shareAmount: shareValue is num
          ? shareValue.toDouble()
          : double.tryParse(shareValue?.toString() ?? "") ?? 0,
    );
  }

  String get displayName {
    final name = "$firstName $lastName".trim();
    return name.isEmpty ? email : name;
  }
}

class SharedExpense {
  final int id;
  final String title;
  final double amount;
  final String expenseDate;
  final BudgetFriend paidByUser;
  final List<SharedExpenseParticipant> participants;

  const SharedExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.expenseDate,
    required this.paidByUser,
    required this.participants,
  });

  factory SharedExpense.fromJson(Map<String, dynamic> json) {
    final amountValue = json["amount"];
    final participantsJson = json["participants"];

    return SharedExpense(
      id: json["id"] as int,
      title: json["title"]?.toString() ?? "",
      amount: amountValue is num
          ? amountValue.toDouble()
          : double.tryParse(amountValue?.toString() ?? "") ?? 0,
      expenseDate: json["expense_date"]?.toString().split("T").first ?? "",
      paidByUser: BudgetFriend.fromJson(
        json["paid_by_user"] as Map<String, dynamic>? ?? {},
      ),
      participants: participantsJson is List
          ? participantsJson
                .whereType<Map<String, dynamic>>()
                .map(SharedExpenseParticipant.fromJson)
                .toList()
          : <SharedExpenseParticipant>[],
    );
  }

  double get shareAmount {
    if (participants.isEmpty) return 0;
    return participants.first.shareAmount;
  }
}

class DebtSettlement {
  final BudgetFriend from;
  final BudgetFriend to;
  final double amount;

  const DebtSettlement({
    required this.from,
    required this.to,
    required this.amount,
  });
}

class SettlementMemberSummary {
  final BudgetFriend member;
  final double paidAmount;
  final double owedShare;
  final double balance;

  const SettlementMemberSummary({
    required this.member,
    required this.paidAmount,
    required this.owedShare,
    required this.balance,
  });

  factory SettlementMemberSummary.fromJson(Map<String, dynamic> json) {
    return SettlementMemberSummary(
      member: BudgetFriend.fromJson(json),
      paidAmount: parseJsonAmount(json["paid_amount"]),
      owedShare: parseJsonAmount(json["owed_share"]),
      balance: parseJsonAmount(json["balance"]),
    );
  }
}

class SettlementSummary {
  final List<SettlementMemberSummary> members;
  final List<DebtSettlement> settlements;

  const SettlementSummary({required this.members, required this.settlements});

  factory SettlementSummary.fromJson(Map<String, dynamic> json) {
    final membersJson = json["members"];
    final settlementsJson = json["settlements"];

    return SettlementSummary(
      members: membersJson is List
          ? membersJson
                .whereType<Map<String, dynamic>>()
                .map(SettlementMemberSummary.fromJson)
                .toList()
          : <SettlementMemberSummary>[],
      settlements: settlementsJson is List
          ? settlementsJson.whereType<Map<String, dynamic>>().map((
              settlementJson,
            ) {
              return DebtSettlement(
                from: BudgetFriend.fromJson(
                  settlementJson["from_user"] as Map<String, dynamic>? ?? {},
                ),
                to: BudgetFriend.fromJson(
                  settlementJson["to_user"] as Map<String, dynamic>? ?? {},
                ),
                amount: parseJsonAmount(settlementJson["amount"]),
              );
            }).toList()
          : <DebtSettlement>[],
    );
  }
}

double parseJsonAmount(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? "") ?? 0;
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
    return BudgetSummary(
      incomeTotal: parseJsonAmount(json["income_total"]),
      expenseTotal: parseJsonAmount(json["expense_total"]),
      sharedExpenseTotal: parseJsonAmount(json["shared_expense_total"]),
      remainingBalance: parseJsonAmount(json["remaining_balance"]),
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
  List<FriendInvitation> incomingInvitations = [];
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
      final invitationsResponse = await widget.httpGet(
        ApiConfig.uri("/budget/friend-invitations"),
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
          invitationsResponse.statusCode != 200 ||
          groupsResponse.statusCode != 200 ||
          transactionsResponse.statusCode != 200) {
        setState(() {
          isLoading = false;
          errorMessage = "Bütçe bilgileri alınamadı.";
        });
        return;
      }

      final friendsData = jsonDecode(friendsResponse.body);
      final invitationsData = jsonDecode(invitationsResponse.body);
      final groupsData = jsonDecode(groupsResponse.body);
      final transactionsData = jsonDecode(transactionsResponse.body);

      setState(() {
        friends = (friendsData["friends"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BudgetFriend.fromJson)
            .toList();
        incomingInvitations =
            (invitationsData["invitations"] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(FriendInvitation.fromJson)
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

  String invitationErrorMessage(String message) {
    if (message == "Friend invitation is already pending") {
      return "Bu kişiye gönderilmiş bekleyen davet var.";
    }

    if (message == "User is already your friend") {
      return "Bu kişi zaten arkadaşların arasında.";
    }

    return "Arkadaş daveti gönderilemedi.";
  }

  double sharedGroupTotal(BudgetGroup group) {
    return group.expenses.fold<double>(
      0,
      (total, expense) => total + expense.amount,
    );
  }

  List<DebtSettlement> calculateSettlements(BudgetGroup group) {
    final balances = <int, double>{};
    final memberById = <int, BudgetFriend>{
      for (final member in group.members) member.id: member,
    };

    for (final member in group.members) {
      balances[member.id] = 0;
    }

    for (final expense in group.expenses) {
      balances[expense.paidByUser.id] =
          (balances[expense.paidByUser.id] ?? 0) + expense.amount;
      memberById[expense.paidByUser.id] = expense.paidByUser;

      for (final participant in expense.participants) {
        balances[participant.id] =
            (balances[participant.id] ?? 0) - participant.shareAmount;
        memberById[participant.id] = BudgetFriend(
          id: participant.id,
          firstName: participant.firstName,
          lastName: participant.lastName,
          email: participant.email,
        );
      }
    }

    final debtors =
        balances.entries
            .where((entry) => entry.value < -0.01)
            .map((entry) => MapEntry(entry.key, -entry.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final creditors =
        balances.entries
            .where((entry) => entry.value > 0.01)
            .map((entry) => MapEntry(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final settlements = <DebtSettlement>[];
    var debtorIndex = 0;
    var creditorIndex = 0;

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];
      final amount = debtor.value < creditor.value
          ? debtor.value
          : creditor.value;

      final from = memberById[debtor.key];
      final to = memberById[creditor.key];

      if (from != null && to != null && amount > 0.01) {
        settlements.add(DebtSettlement(from: from, to: to, amount: amount));
      }

      debtors[debtorIndex] = MapEntry(debtor.key, debtor.value - amount);
      creditors[creditorIndex] = MapEntry(
        creditor.key,
        creditor.value - amount,
      );

      if (debtors[debtorIndex].value <= 0.01) debtorIndex++;
      if (creditors[creditorIndex].value <= 0.01) creditorIndex++;
    }

    return settlements;
  }

  List<SettlementMemberSummary> calculateSettlementMemberSummaries(
    BudgetGroup group,
  ) {
    final paidAmounts = <int, double>{};
    final owedShares = <int, double>{};
    final memberById = <int, BudgetFriend>{
      for (final member in group.members) member.id: member,
    };

    for (final member in group.members) {
      paidAmounts[member.id] = 0;
      owedShares[member.id] = 0;
    }

    for (final expense in group.expenses) {
      paidAmounts[expense.paidByUser.id] =
          (paidAmounts[expense.paidByUser.id] ?? 0) + expense.amount;
      memberById[expense.paidByUser.id] = expense.paidByUser;

      for (final participant in expense.participants) {
        owedShares[participant.id] =
            (owedShares[participant.id] ?? 0) + participant.shareAmount;
        memberById[participant.id] = BudgetFriend(
          id: participant.id,
          firstName: participant.firstName,
          lastName: participant.lastName,
          email: participant.email,
        );
      }
    }

    final summaries = memberById.entries.map((entry) {
      final paidAmount = paidAmounts[entry.key] ?? 0;
      final owedShare = owedShares[entry.key] ?? 0;

      return SettlementMemberSummary(
        member: entry.value,
        paidAmount: paidAmount,
        owedShare: owedShare,
        balance: paidAmount - owedShare,
      );
    }).toList()..sort((a, b) => a.member.id.compareTo(b.member.id));

    return summaries;
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

  Future<void> showCreateSharedExpenseDialog(BudgetGroup group) async {
    if (group.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu grupta gider eklenebilecek üye yok.")),
      );
      return;
    }

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final dateController = TextEditingController(text: currentDateKey());
    final selectedParticipantIds = group.members
        .map((member) => member.id)
        .toSet();

    InputDecoration fieldDecoration(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      );
    }

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF6F2FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF6C63FF,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.add_card_rounded,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${group.name} gideri",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Tutar seçtiğin kişiler arasında eşit bölünecek.",
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.55),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: "Kapat",
                              onPressed: () => Navigator.pop(context, false),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: titleController,
                          decoration: fieldDecoration("Başlık"),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                decoration: fieldDecoration("Tutar"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: dateController,
                                decoration: fieldDecoration(
                                  "Tarih",
                                  hint: "YYYY-AA-GG",
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "Katılımcılar",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...group.members.map((member) {
                          final isSelected = selectedParticipantIds.contains(
                            member.id,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              activeColor: const Color(0xFF6C63FF),
                              title: Text(
                                member.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                member.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedParticipantIds.add(member.id);
                                  } else {
                                    selectedParticipantIds.remove(member.id);
                                  }
                                });
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  "Vazgeç",
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
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
                                      !hasValidDate ||
                                      selectedParticipantIds.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Gider bilgilerini kontrol et.",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.pop(context, true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  "Kaydet",
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (submitted == true) {
      await createSharedExpense(
        group: group,
        title: titleController.text.trim(),
        amount: double.parse(amountController.text.trim()),
        expenseDate: dateController.text.trim(),
        participantIds: selectedParticipantIds.toList(),
      );
    }
  }

  Future<void> createSharedExpense({
    required BudgetGroup group,
    required String title,
    required double amount,
    required String expenseDate,
    required List<int> participantIds,
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
        ApiConfig.uri("/budget/groups/${group.id}/expenses"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode({
          "title": title,
          "amount": amount,
          "expense_date": expenseDate,
          "participant_ids": participantIds,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final expense = SharedExpense.fromJson(
          data["expense"] as Map<String, dynamic>,
        );

        setState(() {
          final groupIndex = groups.indexWhere((item) => item.id == group.id);
          if (groupIndex == -1) return;

          final currentGroup = groups[groupIndex];
          groups[groupIndex] = BudgetGroup(
            id: currentGroup.id,
            name: currentGroup.name,
            members: currentGroup.members,
            expenses: [expense, ...currentGroup.expenses],
            settlementSummary: null,
          );

          if (expense.expenseDate.startsWith(currentMonthKey())) {
            final currentUserShare = expense.participants
                .where((participant) => participant.id == expense.paidByUser.id)
                .fold<double>(
                  0,
                  (total, participant) => total + participant.shareAmount,
                );

            if (currentUserShare > 0) {
              final sharedExpenseTotal =
                  summary.sharedExpenseTotal + currentUserShare;
              summary = BudgetSummary(
                incomeTotal: summary.incomeTotal,
                expenseTotal: summary.expenseTotal,
                sharedExpenseTotal: sharedExpenseTotal,
                remainingBalance:
                    summary.incomeTotal -
                    summary.expenseTotal -
                    sharedExpenseTotal,
              );
            }
          }
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Ortak gider eklendi.")));
        return;
      }

      var message = "Ortak gider eklenemedi.";
      try {
        final data = jsonDecode(response.body);
        message = data["message"]?.toString() ?? message;
      } catch (_) {
        // Keep the fallback message when the server returns a non-JSON error.
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sunucu bağlantısı kurulamadı.")),
      );
    }
  }

  Future<void> showInviteFriendDialog() async {
    final emailController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Arkadaş davet et"),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "E-posta",
              hintText: "arkadas@example.com",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Vazgeç"),
            ),
            TextButton(
              onPressed: () {
                if (!emailController.text.trim().contains("@")) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Geçerli bir e-posta gir.")),
                  );
                  return;
                }

                Navigator.pop(context, true);
              },
              child: const Text("Gönder"),
            ),
          ],
        );
      },
    );

    if (submitted == true) {
      await sendFriendInvitation(emailController.text.trim());
    }
  }

  Future<void> sendFriendInvitation(String email) async {
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
        ApiConfig.uri("/budget/friend-invitations"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode({"email": email}),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Arkadaş daveti gönderildi.")),
        );
        return;
      }

      var message = "Arkadaş daveti gönderilemedi.";
      try {
        final data = jsonDecode(response.body);
        message = invitationErrorMessage(data["message"]?.toString() ?? "");
      } catch (_) {
        // Keep the fallback message when the server returns a non-JSON error.
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sunucu bağlantısı kurulamadı.")),
      );
    }
  }

  Future<void> respondToFriendInvitation({
    required FriendInvitation invitation,
    required String action,
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
        ApiConfig.uri("/budget/friend-invitations/${invitation.id}/respond"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode({"action": action}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          incomingInvitations.removeWhere((item) => item.id == invitation.id);
        });

        if (action == "accept") {
          await fetchBudgetData();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == "accept"
                  ? "Arkadaş daveti kabul edildi."
                  : "Arkadaş daveti reddedildi.",
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Arkadaş daveti güncellenemedi.")),
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatCurrency(summary.remainingBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
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
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                "$prefix${formatCurrency(transaction.amount)}",
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
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
        buildSharedHeader(),
        const SizedBox(height: 14),
        if (incomingInvitations.isNotEmpty) ...[
          buildIncomingInvitationsNotice(),
          const SizedBox(height: 14),
        ],
        const Text(
          "Gruplar",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (groups.isEmpty)
          buildSharedEmptyState()
        else ...[
          ...groups.map(buildGroupCard),
          const SizedBox(height: 8),
        ],
        buildAcceptedFriendsStrip(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget buildSharedHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF222831),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ortak Bütçe",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Gruplarını ve davetlerini buradan yönet.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: showCreateGroupDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.group_add_rounded, size: 16),
                  label: const Text(
                    "Grup Oluştur",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: showInviteFriendDialog,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                label: const Text(
                  "Davet Gönder",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildIncomingInvitationsNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD166),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF5D4200),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Gelen davetler (${incomingInvitations.length})",
                  style: const TextStyle(
                    color: Color(0xFF4A3600),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...incomingInvitations.map(buildInvitationRow),
        ],
      ),
    );
  }

  Widget buildAcceptedFriendsStrip() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: Color(0xFF6C63FF),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: friends.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      "Arkadaş ekleyince ortak gruplara hızlıca dahil edebilirsin.",
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.52),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Kabul edilmiş arkadaşlar",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.56),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: friends.map((friend) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              friend.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
          ),
        ],
      ),
    );
  }

  Widget buildInvitationRow(FriendInvitation invitation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invitation.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2F2500),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  invitation.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.52),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Reddet",
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFECEC),
              foregroundColor: const Color(0xFFC84C4C),
            ),
            onPressed: () => respondToFriendInvitation(
              invitation: invitation,
              action: "reject",
            ),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: "Kabul Et",
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE5F6F4),
              foregroundColor: const Color(0xFF16877C),
            ),
            onPressed: () => respondToFriendInvitation(
              invitation: invitation,
              action: "accept",
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
          ),
        ],
      ),
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
    final total = sharedGroupTotal(group);

    return GestureDetector(
      onTap: () => showGroupDetailsSheet(group),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Color(0xFF6C63FF),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${group.members.length} kişi • ${group.expenses.length} gider",
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.52),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatCurrency(total),
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.black.withOpacity(0.35),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showGroupDetailsSheet(BudgetGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F2FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${group.members.length} kişi • toplam ${formatCurrency(sharedGroupTotal(group))}",
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.56),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: "Kapat",
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showCreateSharedExpenseDialog(group);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_card_rounded),
                      label: const Text(
                        "Gider Ekle",
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  buildGroupSettlementsSection(group),
                  const SizedBox(height: 16),
                  buildGroupExpensesSection(group),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildGroupSettlementsSection(BudgetGroup group) {
    final settlementSummary = group.settlementSummary;
    final settlements =
        settlementSummary?.settlements ?? calculateSettlements(group);
    final memberSummaries =
        settlementSummary?.members ?? calculateSettlementMemberSummaries(group);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Borç Durumu",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (memberSummaries.isNotEmpty) ...[
            ...memberSummaries.map(buildSettlementMemberSummaryRow),
            const SizedBox(height: 8),
          ],
          if (group.expenses.isEmpty)
            Text(
              "Gider eklenince kimin kime ne kadar borçlu olduğu burada görünecek.",
              style: TextStyle(
                color: Colors.black.withOpacity(0.55),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (settlements.isEmpty)
            Text(
              "Herkesin hesabı dengede görünüyor.",
              style: TextStyle(
                color: Colors.black.withOpacity(0.55),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...settlements.map((settlement) {
              return Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: buildSettlementPerson(settlement.from)),
                        Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        Expanded(child: buildSettlementPerson(settlement.to)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${settlement.from.displayName}, ${settlement.to.displayName} kişisine ${formatCurrency(settlement.amount)} ödemeli",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget buildSettlementMemberSummaryRow(SettlementMemberSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary.member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "Ödedi ${formatCurrency(summary.paidAmount)} • Payı ${formatCurrency(summary.owedShare)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black.withOpacity(0.56),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSettlementPerson(BudgetFriend friend) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            friend.displayName.isEmpty
                ? "?"
                : friend.displayName.characters.first.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          friend.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget buildGroupExpensesSection(BudgetGroup group) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Harcamalar",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (group.expenses.isEmpty)
            Text(
              "Bu grupta henüz ortak gider yok.",
              style: TextStyle(
                color: Colors.black.withOpacity(0.52),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...group.expenses.map(buildSharedExpenseRow),
        ],
      ),
    );
  }

  Widget buildSharedExpenseRow(SharedExpense expense) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF6C63FF),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${expense.paidByUser.displayName} ödedi • ${expense.participants.length} kişi • kişi başı ${formatCurrency(expense.shareAmount)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.52),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatCurrency(expense.amount),
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
