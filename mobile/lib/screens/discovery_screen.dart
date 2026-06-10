import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/token_storage.dart';
import '../widgets/app_bottom_navigation_bar.dart';

enum HabitFilter { morning, all, evening }

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

class HabitTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final int habitCount;
  final bool isFeatured;
  final bool isAdded;
  final List<String> habits;
  final Color categoryColor;
  final IconData categoryIcon;

  const HabitTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.habitCount,
    required this.isFeatured,
    required this.isAdded,
    required this.habits,
    required this.categoryColor,
    required this.categoryIcon,
  });

  factory HabitTemplate.fromJson(Map<String, dynamic> json) {
    final category = json["category"]?.toString() ?? "General";
    final habitsJson = json["habits"] as List<dynamic>? ?? [];
    final habits = habitsJson
        .map((item) {
          if (item is Map<String, dynamic>) {
            return item["name"]?.toString() ?? "";
          }
          return item.toString();
        })
        .where((name) => name.isNotEmpty)
        .toList();

    return HabitTemplate(
      id: json["id"].toString(),
      title: json["title"]?.toString() ?? "",
      description: json["description"]?.toString() ?? "",
      category: category,
      imageUrl: json["image_url"]?.toString() ?? "",
      habitCount: json["habit_count"] is int
          ? json["habit_count"]
          : habits.length,
      isFeatured: json["is_featured"] == true,
      isAdded: json["is_added"] == true,
      habits: habits,
      categoryColor: _categoryColorFor(category),
      categoryIcon: _categoryIconFor(category),
    );
  }
}

Color _categoryColorFor(String category) {
  switch (category) {
    case 'Fitness':
      return const Color(0xFF8DB4FF);
    case 'Productivity':
      return const Color(0xFFFFB86B);
    case 'Wellness':
      return const Color(0xFFA78BFA);
    case 'Learning':
      return const Color(0xFF26A69A);
    default:
      return const Color(0xFF6C63FF);
  }
}

IconData _categoryIconFor(String category) {
  switch (category) {
    case 'Fitness':
      return Icons.fitness_center_rounded;
    case 'Productivity':
      return Icons.bolt_rounded;
    case 'Wellness':
      return Icons.self_improvement_rounded;
    case 'Learning':
      return Icons.menu_book_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}

// ─────────────────────────────────────────────
// DISCOVERY PAGE
// ─────────────────────────────────────────────

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final Set<String> _loadingTemplates = {};
  Set<String> _addedTemplates = {};
  List<HabitTemplate> _templates = [];
  String _selectedCategory = 'All';
  bool _isLoadingTemplates = true;
  String? _loadErrorMessage;

  final HabitFilter currentFilter = HabitFilter.all;

  List<String> get _categories {
    final categories = _templates.map((t) => t.category).toSet().toList()
      ..sort();
    return ['All', ...categories];
  }

  @override
  void initState() {
    super.initState();
    _fetchTemplates();
  }

  Color getBackgroundColor() {
    if (currentFilter == HabitFilter.evening) return const Color(0xFF1F2633);
    return const Color(0xFFF6F2FF);
  }

  Color getPrimaryTextColor() {
    if (currentFilter == HabitFilter.evening) return Colors.white;
    return Colors.black;
  }

  Color getCardColor() {
    if (currentFilter == HabitFilter.evening) return const Color(0xFF2B3445);
    return const Color(0xFFFFFCFA);
  }

  List<HabitTemplate> get _featuredTemplates =>
      _templates.where((t) => t.isFeatured).toList();

  List<HabitTemplate> get _filteredTemplates {
    final nonFeatured = _templates.where((t) => !t.isFeatured).toList();
    if (_selectedCategory == 'All') return nonFeatured;
    return nonFeatured.where((t) => t.category == _selectedCategory).toList();
  }

  Map<String, List<HabitTemplate>> get _templatesByCategory {
    final map = <String, List<HabitTemplate>>{};
    for (final t in _filteredTemplates) {
      map.putIfAbsent(t.category, () => []).add(t);
    }
    return map;
  }

  Future<void> _fetchTemplates() async {
    setState(() {
      _isLoadingTemplates = true;
      _loadErrorMessage = null;
    });

    try {
      final accessToken = await TokenStorage.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isLoadingTemplates = false;
          _loadErrorMessage = "Oturum bulunamadı.";
        });
        return;
      }

      final response = await http.get(
        ApiConfig.uri("/habit-templates"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> templatesJson = data["templates"] ?? [];

        setState(() {
          _templates = templatesJson
              .whereType<Map<String, dynamic>>()
              .map(HabitTemplate.fromJson)
              .toList();
          _addedTemplates = _templates
              .where((template) => template.isAdded)
              .map((template) => template.id)
              .toSet();
          _isLoadingTemplates = false;
        });
        return;
      }

      setState(() {
        _isLoadingTemplates = false;
        _loadErrorMessage = "Şablonlar alınamadı.";
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingTemplates = false;
        _loadErrorMessage = "Sunucu bağlantısı kurulamadı.";
      });
    }
  }

  Future<void> _addTemplate(HabitTemplate template) async {
    if (_loadingTemplates.contains(template.id)) return;

    HapticFeedback.mediumImpact();
    setState(() => _loadingTemplates.add(template.id));

    try {
      final accessToken = await TokenStorage.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;

        setState(() => _loadingTemplates.remove(template.id));
        _showErrorToast("Oturum bulunamadı.");
        return;
      }

      final response = await http.post(
        ApiConfig.uri("/habit-templates/${template.id}/add"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 409) {
        setState(() {
          _loadingTemplates.remove(template.id);
          _addedTemplates.add(template.id);
        });
        _showErrorToast("Bu plan zaten listende.");
        return;
      }

      if (response.statusCode != 201) {
        setState(() => _loadingTemplates.remove(template.id));
        _showErrorToast("Plan eklenirken bir hata oluştu.");
        return;
      }

      final data = jsonDecode(response.body);
      final addedCount = data["addedCount"] is int
          ? data["addedCount"]
          : template.habitCount;

      setState(() {
        _loadingTemplates.remove(template.id);
        _addedTemplates.add(template.id);
      });

      _showSuccessToast(addedCount);
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingTemplates.remove(template.id));
      _showErrorToast("Sunucu bağlantısı kurulamadı.");
    }
  }

  void _showSuccessToast(int addedCount) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: _ToastWidget(
          message: '$addedCount alışkanlık listene eklendi!',
          isSuccess: true,
        ),
      ),
    );
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: _ToastWidget(message: message, isSuccess: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: getBackgroundColor(),
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 1),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          if (_isLoadingTemplates)
            _buildLoadingState()
          else if (_loadErrorMessage != null)
            _buildErrorState()
          else ...[
            _buildCategoryFilter(),
            _buildFeaturedSection(),
            _buildCategorySections(),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SliverFillRemaining(
      hasScrollBody: false,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 42, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _loadErrorMessage ?? "Şablonlar alınamadı.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: getPrimaryTextColor().withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _fetchTemplates,
                child: const Text("Tekrar dene"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── APP BAR (Gelişmiş Katlanma ve Geçiş Animasyonlu) ──────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 70,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: getBackgroundColor(),
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,

      // Buradaki title'ı boş bırakıyoruz çünkü FlexibleSpaceBar kendi başlığını yönetecek
      title: const SizedBox.shrink(),

      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true, // Katlandığında başlığın tam ortada durmasını sağlar
        // Bu başlık SAYFA KATLANDIĞINDA yukarıda belirecek olan küçük yazıdır
        title: Text(
          'Keşfet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: getPrimaryTextColor(),
          ),
        ),

        // Bu kısım ise SAYFA EN YUKARIDAYKEN gözükecek büyük başlık ve açıklamadır
      ),
    );
  }
  // ── CATEGORY FILTER ───────────────────────────

  Widget _buildCategoryFilter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 0.01),
        child: SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : getCardColor(),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.black.withOpacity(0.08),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      cat == 'All' ? 'Tümü' : cat,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : getPrimaryTextColor().withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── FEATURED SECTION ──────────────────────────

  Widget _buildFeaturedSection() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Color(0xFFFFB86B),
                ),
                const SizedBox(width: 6),
                Text(
                  'Öne Çıkanlar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: getPrimaryTextColor(),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: _featuredTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) => _FeaturedTemplateCard(
                template: _featuredTemplates[index],
                isLoading: _loadingTemplates.contains(
                  _featuredTemplates[index].id,
                ),
                isAdded: _addedTemplates.contains(_featuredTemplates[index].id),
                onAdd: () => _addTemplate(_featuredTemplates[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CATEGORY SECTIONS ─────────────────────────

  Widget _buildCategorySections() {
    final grouped = _templatesByCategory;
    if (grouped.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu kategoride plan bulunamadı.',
                  style: TextStyle(
                    color: getPrimaryTextColor().withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final category = grouped.keys.elementAt(index);
        final templates = grouped[category]!;
        return _CategorySection(
          category: category,
          templates: templates,
          loadingIds: _loadingTemplates,
          addedIds: _addedTemplates,
          onAdd: _addTemplate,
          cardColor: getCardColor(),
          textColor: getPrimaryTextColor(),
        );
      }, childCount: grouped.length),
    );
  }
}

// ─────────────────────────────────────────────
// FEATURED TEMPLATE CARD
// ─────────────────────────────────────────────

class _FeaturedTemplateCard extends StatelessWidget {
  final HabitTemplate template;
  final bool isLoading;
  final bool isAdded;
  final VoidCallback onAdd;

  const _FeaturedTemplateCard({
    required this.template,
    required this.isLoading,
    required this.isAdded,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: template.categoryColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                template.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: template.categoryColor.withOpacity(0.15)),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: template.categoryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(template.categoryIcon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      template.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${template.habitCount} alışkanlık',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AddButton(
                      isLoading: isLoading,
                      isAdded: isAdded,
                      onAdd: onAdd,
                      compact: true,
                      accentColor: template.categoryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CATEGORY SECTION
// ─────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<HabitTemplate> templates;
  final Set<String> loadingIds;
  final Set<String> addedIds;
  final Function(HabitTemplate) onAdd;
  final Color cardColor;
  final Color textColor;

  const _CategorySection({
    required this.category,
    required this.templates,
    required this.loadingIds,
    required this.addedIds,
    required this.onAdd,
    required this.cardColor,
    required this.textColor,
  });

  Color get _categoryColor => templates.first.categoryColor;
  IconData get _categoryIcon => templates.first.categoryIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon, size: 16, color: _categoryColor),
                ),
                const SizedBox(width: 10),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          ...templates.map(
            (t) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _ListTemplateCard(
                template: t,
                isLoading: loadingIds.contains(t.id),
                isAdded: addedIds.contains(t.id),
                onAdd: () => onAdd(t),
                cardColor: cardColor,
                textColor: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LIST TEMPLATE CARD
// ─────────────────────────────────────────────

class _ListTemplateCard extends StatelessWidget {
  final HabitTemplate template;
  final bool isLoading;
  final bool isAdded;
  final VoidCallback onAdd;
  final Color cardColor;
  final Color textColor;

  const _ListTemplateCard({
    required this.template,
    required this.isLoading,
    required this.isAdded,
    required this.onAdd,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(26),
            ),
            child: SizedBox(
              width: 90,
              height: 90,
              child: Image.network(
                template.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: template.categoryColor.withOpacity(0.15),
                  child: Icon(
                    template.categoryIcon,
                    color: template.categoryColor,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: template.categoryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      template.category,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: template.categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    template.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${template.habitCount} alışkanlık içeriyor',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _AddButton(
              isLoading: isLoading,
              isAdded: isAdded,
              onAdd: onAdd,
              compact: false,
              accentColor: template.categoryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD BUTTON
// ─────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final bool isLoading;
  final bool isAdded;
  final VoidCallback onAdd;
  final bool compact;
  final Color accentColor;

  const _AddButton({
    required this.isLoading,
    required this.isAdded,
    required this.onAdd,
    required this.compact,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return GestureDetector(
        onTap: isAdded ? null : onAdd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isAdded ? Colors.white.withOpacity(0.25) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6C63FF),
                    ),
                  )
                : isAdded
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : const Text(
                    'Ekle',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: isAdded ? null : onAdd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isAdded
              ? const Color(0xFF26A69A)
              : accentColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isAdded ? Colors.white : accentColor,
                  ),
                )
              : Icon(
                  isAdded ? Icons.check_rounded : Icons.add_rounded,
                  color: isAdded ? Colors.white : accentColor.withOpacity(0.9),
                  size: 20,
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TOAST WIDGET
// ─────────────────────────────────────────────

class _ToastWidget extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _ToastWidget({required this.message, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFF6C63FF) : const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
