import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

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

  String capitalizeName(String value) {
    final text = value.trim();

    if (text.isEmpty) return text;

    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = capitalizeName(nameController.text);
    final surname = capitalizeName(surnameController.text);
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:3000/users/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "firstName": name,
          "lastName": surname,
          "email": email,
          "password": password,
        }),
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        showSuccessBanner("Kayıt başarılı.");

        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
        return;
      }

      if (response.statusCode == 409) {
        showErrorBanner("Bu mail kullanılıyor.");
        return;
      }

      if (response.statusCode == 400) {
        try {
          final data = jsonDecode(response.body);
          final message = data["message"] ?? "Kayıt başarısız.";
          showErrorBanner(message);
        } catch (_) {
          showErrorBanner("Kayıt başarısız. Lütfen tekrar deneyin.");
        }
        return;
      }

      showErrorBanner("Kayıt başarısız. Lütfen tekrar deneyin.");
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
      hintStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      errorStyle: const TextStyle(
        color: Colors.redAccent,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white70, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background_login.jpg'),
            fit: BoxFit.cover,
          ),
        ),
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
                        const Text(
                          'Register',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "Name",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: nameController,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: customInputDecoration(
                                    "Enter your name",
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? "";

                                    if (text.isEmpty) {
                                      return "İsim zorunludur";
                                    }

                                    return null;
                                  },
                                ),

                                const SizedBox(height: 18),

                                const Text(
                                  "Surname",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: surnameController,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: customInputDecoration(
                                    "Enter your surname",
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? "";

                                    if (text.isEmpty) {
                                      return "Soyisim zorunludur";
                                    }

                                    return null;
                                  },
                                ),

                                const SizedBox(height: 18),

                                const Text(
                                  "Email",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: customInputDecoration(
                                    "Enter your email",
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
                                  "Password",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: customInputDecoration(
                                    "Enter your password",
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? "";

                                    if (text.isEmpty) {
                                      return "Şifre zorunludur";
                                    }

                                    if (text.length < 6) {
                                      return "Şifre en az 6 karakter olmalıdır";
                                    }

                                    return null;
                                  },
                                ),

                                const SizedBox(height: 18),

                                const Text(
                                  "Confirm Password",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: confirmPasswordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    if (!isLoading) {
                                      registerUser();
                                    }
                                  },
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: customInputDecoration(
                                    "Enter your password again",
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? "";
                                    final password = passwordController.text
                                        .trim();

                                    if (text.isEmpty) {
                                      return "Şifre tekrarı zorunludur";
                                    }

                                    if (text != password) {
                                      return "Şifreler uyuşmuyor";
                                    }

                                    return null;
                                  },
                                ),

                                const SizedBox(height: 24),

                                SizedBox(
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: isLoading ? null : registerUser,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      foregroundColor: Colors.white,
                                      backgroundColor: Colors.transparent,
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
                                            "Kayıt Ol",
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
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    "Back to Login",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
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
                    color: backgroundColor.withOpacity(0.95),
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

// class _RegisterScreenState extends State<RegisterScreen> {
//   String? nameError;
//   String? surnameError;
//   String? emailError;
//   String? passwordError;
//   String? confirmPasswordError;

//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController surnameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final TextEditingController confirmPasswordController =
//       TextEditingController();

//   String? passwordErrorText;
//   String? emptyErrorText;
//   bool isLoading = false;

//   void showTopBanner({required String message, required bool isSuccess}) {
//     final overlay = Overlay.of(context);
//     late OverlayEntry overlayEntry;

//     overlayEntry = OverlayEntry(
//       builder: (context) => _TopBanner(
//         message: message,
//         isSuccess: isSuccess,
//         onDismissed: () {
//           overlayEntry.remove();
//         },
//       ),
//     );

//     overlay.insert(overlayEntry);
//   }

//   void showSuccessBanner(String message) {
//     showTopBanner(message: message, isSuccess: true);
//   }

//   void showErrorBanner(String message) {
//     showTopBanner(message: message, isSuccess: false);
//   }

//   Future<void> registerUser() async {
//     final name = nameController.text.trim();
//     final surname = surnameController.text.trim();
//     final email = emailController.text.trim();
//     final password = passwordController.text.trim();
//     final confirmPassword = confirmPasswordController.text.trim();

//     bool hasError = false;

//     setState(() {
//       nameError = null;
//       surnameError = null;
//       emailError = null;
//       passwordError = null;
//       confirmPasswordError = null;
//       passwordErrorText = null;

//       if(name.isEmpty) {
//         NAMEE
//       }

//     });

//     // if (name.isEmpty ||
//     //     surname.isEmpty ||
//     //     email.isEmpty ||
//     //     password.isEmpty ||
//     //     confirmPassword.isEmpty) {
//     //   showErrorBanner("Lütfen Tüm Alanları Doldurun.");
//     //   return;

//     //   //   showErrorBanner("Lütfen tüm alanları doldurun.");
//     //   //   return;
//     // }

//     if (password != confirmPassword) {
//       setState(() {
//         passwordErrorText = "Şifreler uyuşmuyor";
//       });
//       return;
//     }

//     setState(() {
//       passwordErrorText = null;
//       isLoading = true;
//     });

//     try {
//       final response = await http.post(
//         Uri.parse("http://10.0.2.2:3000/users/register"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "firstName": name,
//           "lastName": surname,
//           "email": email,
//           "password": password,
//         }),
//       );

//       if (!mounted) return;

//       setState(() {
//         isLoading = false;
//       });

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         showSuccessBanner("Kayıt başarılı.");
//         Future.delayed(const Duration(milliseconds: 600), () {
//           if (mounted) {
//             Navigator.pop(context);
//           }
//         });
//         return;
//       }

//       if (response.statusCode == 409) {
//         showErrorBanner("Bu mail kullanılıyor.");
//         return;
//       }

//       showErrorBanner("Kayıt başarısız. Lütfen tekrar deneyin.");
//     } catch (e) {
//       if (!mounted) return;

//       setState(() {
//         isLoading = false;
//       });

//       showErrorBanner("Bir hata oluştu. Sunucu bağlantısını kontrol edin.");
//     }
//   }

//   @override
//   void dispose() {
//     nameController.dispose();
//     surnameController.dispose();
//     emailController.dispose();
//     passwordController.dispose();
//     confirmPasswordController.dispose();
//     super.dispose();
//   }

//   void validatePasswords() {
//     final password = passwordController.text.trim();
//     final confirmPassword = confirmPasswordController.text.trim();

//     setState(() {
//       if (confirmPassword.isNotEmpty && password != confirmPassword) {
//         passwordErrorText = "Şifreler uyuşmuyor";
//       } else {
//         passwordErrorText = null;
//       }
//     });
//   }

//   InputDecoration customInputDecoration(String hintText) {
//     return InputDecoration(
//       hintText: hintText,
//       hintStyle: const TextStyle(
//         color: Colors.white,
//         fontWeight: FontWeight.w500,
//       ),
//       filled: true,
//       fillColor: Colors.white.withOpacity(0.15),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(14),
//         borderSide: const BorderSide(color: Colors.white70, width: 1.2),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(14),
//         borderSide: const BorderSide(color: Colors.white, width: 1.5),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       body: Container(
//         width: double.infinity,
//         height: double.infinity,
//         decoration: const BoxDecoration(
//           image: DecorationImage(
//             image: AssetImage('assets/images/background_login.jpg'),
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: SafeArea(
//           child: LayoutBuilder(
//             builder: (context, constraints) {
//               return SingleChildScrollView(
//                 keyboardDismissBehavior:
//                     ScrollViewKeyboardDismissBehavior.onDrag,
//                 padding: EdgeInsets.fromLTRB(32, 24, 32, 24 + keyboardHeight),
//                 child: ConstrainedBox(
//                   constraints: BoxConstraints(
//                     minHeight: constraints.maxHeight - 48,
//                   ),
//                   child: IntrinsicHeight(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Spacer(),

//                         const Text(
//                           'Register',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 52,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),

//                         const SizedBox(height: 24),

//                         Container(
//                           width: double.infinity,
//                           padding: const EdgeInsets.all(24),
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.20),
//                             borderRadius: BorderRadius.circular(24),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.stretch,
//                             children: [
//                               const Text(
//                                 "Name",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               TextField(
//                                 controller: nameController,
//                                 textInputAction: TextInputAction.next,
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                                 decoration: customInputDecoration(
//                                   "Enter your name",
//                                 ),
//                               ),

//                               const SizedBox(height: 18),

//                               const Text(
//                                 "Surname",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               TextField(
//                                 controller: surnameController,
//                                 textInputAction: TextInputAction.next,
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                                 decoration: customInputDecoration(
//                                   "Enter your surname",
//                                 ),
//                               ),

//                               const SizedBox(height: 18),

//                               const Text(
//                                 "Email",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               TextField(
//                                 controller: emailController,
//                                 keyboardType: TextInputType.emailAddress,
//                                 autocorrect: false,
//                                 enableSuggestions: false,
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                                 decoration: customInputDecoration(
//                                   "Enter your email",
//                                 ),
//                               ),

//                               const SizedBox(height: 18),

//                               const Text(
//                                 "Password",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               TextField(
//                                 controller: passwordController,
//                                 obscureText: true,
//                                 textInputAction: TextInputAction.next,
//                                 onChanged: (_) => validatePasswords(),
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                                 decoration: customInputDecoration(
//                                   "Enter your password",
//                                 ),
//                               ),

//                               const SizedBox(height: 18),

//                               const Text(
//                                 "Confirm Password",
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               TextField(
//                                 controller: confirmPasswordController,
//                                 obscureText: true,
//                                 textInputAction: TextInputAction.done,
//                                 onChanged: (_) => validatePasswords(),
//                                 onSubmitted: (_) {
//                                   if (!isLoading) {
//                                     registerUser();
//                                   }
//                                 },
//                                 style: const TextStyle(
//                                   color: Colors.black,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                                 decoration: customInputDecoration(
//                                   "Enter your password again",
//                                 ),
//                               ),

//                               if (passwordErrorText != null) ...[
//                                 const SizedBox(height: 6),
//                                 Text(
//                                   passwordErrorText!,
//                                   style: const TextStyle(
//                                     color: Colors.redAccent,
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ],

//                               const SizedBox(height: 24),

//                               SizedBox(
//                                 height: 52,
//                                 child: OutlinedButton(
//                                   onPressed: isLoading ? null : registerUser,
//                                   style: OutlinedButton.styleFrom(
//                                     side: const BorderSide(
//                                       color: Colors.white,
//                                       width: 1.5,
//                                     ),
//                                     foregroundColor: Colors.white,
//                                     backgroundColor: Colors.transparent,
//                                     shape: RoundedRectangleBorder(
//                                       borderRadius: BorderRadius.circular(14),
//                                     ),
//                                   ),
//                                   child: isLoading
//                                       ? const SizedBox(
//                                           width: 22,
//                                           height: 22,
//                                           child: CircularProgressIndicator(
//                                             strokeWidth: 2,
//                                             color: Colors.white,
//                                           ),
//                                         )
//                                       : const Text(
//                                           "Kayıt Ol",
//                                           style: TextStyle(
//                                             fontWeight: FontWeight.w600,
//                                             fontSize: 16,
//                                           ),
//                                         ),
//                                 ),
//                               ),

//                               const SizedBox(height: 12),

//                               TextButton(
//                                 onPressed: () {
//                                   Navigator.pop(context);
//                                 },
//                                 child: const Text(
//                                   "Back to Login",
//                                   style: TextStyle(
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         const Spacer(),
//                       ],
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _TopBanner extends StatefulWidget {
//   final String message;
//   final bool isSuccess;
//   final VoidCallback onDismissed;

//   const _TopBanner({
//     required this.message,
//     required this.isSuccess,
//     required this.onDismissed,
//   });

//   @override
//   State<_TopBanner> createState() => _TopBannerState();
// }

// class _TopBannerState extends State<_TopBanner>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;
//   late final Animation<Offset> _slideAnimation;
//   late final Animation<double> _fadeAnimation;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 350),
//     );

//     _slideAnimation = Tween<Offset>(
//       begin: const Offset(0, -1.2),
//       end: Offset.zero,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

//     _fadeAnimation = Tween<double>(
//       begin: 0,
//       end: 1,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

//     _controller.forward();

//     Future.delayed(const Duration(seconds: 3), () async {
//       if (!mounted) return;
//       await _controller.reverse();
//       widget.onDismissed();
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final Color backgroundColor = widget.isSuccess
//         ? const Color(0xFF1F8A5B)
//         : const Color(0xFFD64545);

//     final IconData icon = widget.isSuccess
//         ? Icons.check_circle_rounded
//         : Icons.error_rounded;

//     return SafeArea(
//       child: Align(
//         alignment: Alignment.topCenter,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
//           child: FadeTransition(
//             opacity: _fadeAnimation,
//             child: SlideTransition(
//               position: _slideAnimation,
//               child: Material(
//                 color: Colors.transparent,
//                 child: Container(
//                   width: double.infinity,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 14,
//                   ),
//                   decoration: BoxDecoration(
//                     color: backgroundColor.withOpacity(0.95),
//                     borderRadius: BorderRadius.circular(18),
//                     boxShadow: const [
//                       BoxShadow(
//                         color: Colors.black26,
//                         blurRadius: 16,
//                         offset: Offset(0, 8),
//                       ),
//                     ],
//                   ),
//                   child: Row(
//                     children: [
//                       Icon(icon, color: Colors.white, size: 24),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Text(
//                           widget.message,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
