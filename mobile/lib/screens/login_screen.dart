import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../navigation/no_transition_page_route.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import '../services/token_storage.dart';

typedef HttpPost =
    Future<http.Response> Function(
      Uri url, {
      Map<String, String>? headers,
      Object? body,
    });

typedef SaveTokens =
    Future<void> Function({
      required String accessToken,
      required String refreshToken,
    });

class LoginScreen extends StatefulWidget {
  final HttpPost httpPost;
  final SaveTokens saveTokens;
  final bool navigateOnSuccess;
  final WidgetBuilder homeBuilder;

  const LoginScreen({
    super.key,
    this.httpPost = http.post,
    this.saveTokens = TokenStorage.saveTokens,
    this.navigateOnSuccess = true,
    this.homeBuilder = _defaultHomeBuilder,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  void showTopBanner({required String message, required bool isSuccess}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _TopBanner(
        message: message,
        isSuccess: isSuccess,
        onDismissed: () {
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }

  void showSuccessBanner(String message) {
    showTopBanner(message: message, isSuccess: true);
  }

  void showErrorBanner(String message) {
    showTopBanner(message: message, isSuccess: false);
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    setState(() {
      isLoading = true;
    });

    try {
      final response = await widget
          .httpPost(
            ApiConfig.uri("/users/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data["accessToken"];
        final refreshToken = data["refreshToken"];

        if (accessToken == null ||
            refreshToken == null ||
            accessToken.toString().isEmpty ||
            refreshToken.toString().isEmpty) {
          showErrorBanner("Sunucudan geçerli token alınamadı.");
          return;
        }

        await widget.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        showSuccessBanner("Giriş başarılı");

        if (!widget.navigateOnSuccess) {
          return;
        }

        Future.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            NoTransitionPageRoute(builder: widget.homeBuilder),
          );
        });

        return;
      }

      if (response.statusCode == 400 || response.statusCode == 401) {
        try {
          final data = jsonDecode(response.body);
          final message = data["message"] ?? "Email veya şifre hatalı.";
          showErrorBanner(message);
        } catch (_) {
          showErrorBanner("Email veya şifre hatalı.");
        }
        return;
      }

      showErrorBanner("Giriş başarısız. Lütfen tekrar deneyin.");
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showErrorBanner("Bir hata oluştu. Sunucu bağlantısını kontrol edin.");
    }
  }

  InputDecoration customInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.black.withValues(alpha: 0.38),
        fontWeight: FontWeight.w600,
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFC84C4C),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F5FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8E1F5), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC84C4C), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFC84C4C), width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFFF6F2FF),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(32, 24, 32, 24 + keyboardHeight),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Spacer(),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF6C63FF),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'LifeOS',
                          style: TextStyle(
                            color: Color(0xFF222831),
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Günlük düzenine kaldığın yerden devam et.',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.56),
                            fontSize: 15,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 24,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "Email",
                                  style: TextStyle(
                                    color: Color(0xFF222831),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    color: Color(0xFF222831),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: customInputDecoration(
                                    "Email adresin",
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? "";

                                    if (text.isEmpty) {
                                      return "Email zorunludur";
                                    }

                                    final emailRegex = RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    );

                                    if (!emailRegex.hasMatch(text)) {
                                      return "Geçerli bir email girin";
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  "Şifre",
                                  style: TextStyle(
                                    color: Color(0xFF222831),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    if (!isLoading) {
                                      loginUser();
                                    }
                                  },
                                  style: const TextStyle(
                                    color: Color(0xFF222831),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  decoration: customInputDecoration("Şifren"),
                                  validator: (value) {
                                    final text = value?.trim() ?? "";

                                    if (text.isEmpty) {
                                      return "Şifre zorunludur";
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: isLoading ? null : loginUser,
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: const Color(0xFF6C63FF),
                                      disabledBackgroundColor: const Color(
                                        0xFFB9B3EA,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            "Giriş Yap",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      NoTransitionPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Kayıt Ol",
                                    style: TextStyle(
                                      color: Color(0xFF6C63FF),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
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
}

Widget _defaultHomeBuilder(BuildContext context) => const HomePage();

class _TopBanner extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onDismissed;

  const _TopBanner({
    required this.message,
    required this.isSuccess,
    required this.onDismissed,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      await _controller.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = widget.isSuccess
        ? const Color(0xFF1F8A5B)
        : const Color(0xFFD64545);

    final IconData icon = widget.isSuccess
        ? Icons.check_circle_rounded
        : Icons.error_rounded;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
