import 'package:flutter/material.dart';
import 'register_screen.dart';
import '../../main.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double bannerHeight = MediaQuery.of(context).size.height * 0.38;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 🔥 BANNER
          SizedBox(
            height: bannerHeight,
            width: double.infinity,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                  child: Image.asset(
                    "assets/images/banner_dn.png",
                    width: double.infinity,
                    height: bannerHeight,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) {
                      return Container(
                        color: Colors.grey,
                        child: Icon(Icons.image, size: 50),
                      );
                    },
                  ),
                ),

                // overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // 🔙 BACK BUTTON
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),

                // 🔤 TITLE
                Positioned(
                  bottom: 30,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "VietLens",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🧾 FORM
          Expanded(
            child: Transform.translate(
              offset: Offset(0, -20),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 15,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Đăng nhập",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        "Chào mừng bạn trở lại!",
                        style: TextStyle(color: Colors.grey[600]),
                      ),

                      SizedBox(height: 20),

                      // EMAIL
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email),
                          hintText: "Email",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      SizedBox(height: 12),

                      // PASSWORD
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock),
                          hintText: "Mật khẩu",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Quên mật khẩu?",
                          style: TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ),

                      SizedBox(height: 20),

                      // BUTTON LOGIN
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF4CAF50),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (emailController.text.isEmpty ||
                                passwordController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Vui lòng nhập đầy đủ thông tin",
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              await FirebaseAuth.instance
                                  .signInWithEmailAndPassword(
                                    email: emailController.text.trim(),
                                    password: passwordController.text.trim(),
                                  );

                              await FirebaseAuth.instance.currentUser!.reload();
                              await ApiService.syncCurrentUser();

                              if (!context.mounted) return;

                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => HomeScreen()),
                                (route) => false,
                              );
                            } catch (e) {
                              String message = "Đăng nhập thất bại";

                              if (e is FirebaseAuthException) {
                                if (e.code == 'user-not-found') {
                                  message = "Email chưa đăng ký";
                                } else if (e.code == 'wrong-password') {
                                  message = "Sai mật khẩu";
                                } else if (e.code == 'invalid-email') {
                                  message = "Email không hợp lệ";
                                } else if (e.code == 'user-disabled') {
                                  message = "Tài khoản đã bị khóa";
                                }
                              }

                              if (!context.mounted) return;

                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            }
                          },
                          child: Text(
                            "Đăng nhập",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // DIVIDER
                      Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text("Hoặc"),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),

                      SizedBox(height: 15),

                      // SOCIAL
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _socialButton(Icons.g_mobiledata),
                          _socialButton(Icons.facebook),
                          _socialButton(Icons.apple),
                        ],
                      ),

                      SizedBox(height: 20),

                      // REGISTER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Chưa có tài khoản? "),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RegisterScreen(),
                                ),
                              );
                            },
                            child: Text(
                              "Đăng ký ngay",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  Widget _socialButton(IconData icon) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: Colors.grey[200],
      child: Icon(icon, size: 28),
    );
  }
}
