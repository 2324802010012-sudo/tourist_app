import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();

    // ❌ validate
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")));
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Mật khẩu không khớp")));
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mật khẩu phải có tối thiểu 6 ký tự")),
      );
      return;
    }

    try {
      // 🔥 Firebase đăng ký
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 👉 cập nhật tên
      await userCredential.user!.updateDisplayName(name);
      await ApiService.syncCurrentUser();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Đăng ký thành công")));

      // 👉 quay về login
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = "Đăng ký thất bại";

      if (e.code == 'email-already-in-use') {
        message = "Email đã tồn tại";
      } else if (e.code == 'weak-password') {
        message = "Mật khẩu quá yếu";
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌄 BACKGROUND
          Positioned.fill(
            child: Image.asset(
              "assets/images/banner_dk.png",
              fit: BoxFit.cover,
            ),
          ),

          // 🌫️ OVERLAY
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),

          SafeArea(
            child: Column(
              children: [
                // 🔙 HEADER (GIỮ TRÊN)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Đăng ký",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔥 ĐẨY FORM XUỐNG
                SizedBox(height: 300),

                // 🧾 FORM
                Expanded(
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, 25, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // 🔝 FORM TRÊN
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Đăng ký tài khoản",
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      SizedBox(height: 6),

                                      Text(
                                        "Tạo tài khoản để trải nghiệm ngay!",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),

                                      SizedBox(height: 20),

                                      _input(
                                        controller: nameController,
                                        icon: Icons.person,
                                        hint: "Họ và tên",
                                      ),

                                      SizedBox(height: 12),

                                      _input(
                                        controller: emailController,
                                        icon: Icons.email,
                                        hint: "Email",
                                      ),

                                      SizedBox(height: 12),

                                      _input(
                                        controller: passwordController,
                                        icon: Icons.lock,
                                        hint: "Mật khẩu",
                                        isPassword: true,
                                      ),

                                      SizedBox(height: 12),

                                      _input(
                                        controller: confirmController,
                                        icon: Icons.lock,
                                        hint: "Xác nhận mật khẩu",
                                        isPassword: true,
                                      ),
                                    ],
                                  ),

                                  // 🔽 PHẦN DƯỚI
                                  Column(
                                    children: [
                                      SizedBox(height: 20),

                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF4CAF50),
                                            padding: EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: register,
                                          child: Text("Đăng ký"),
                                        ),
                                      ),

                                      SizedBox(height: 15),

                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text("Đã có tài khoản? "),
                                          GestureDetector(
                                            onTap: () => Navigator.pop(context),
                                            child: Text(
                                              "Đăng nhập ngay",
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 10),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔧 INPUT (ĐẶT NGOÀI build)
  Widget _input({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
