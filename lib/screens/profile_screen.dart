import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text("Tài khoản"), centerTitle: true),
      body: user == null
          ? Center(child: Text("Chưa đăng nhập"))
          : Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(height: 30),

                  // 👤 AVATAR
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 45, color: Colors.white),
                  ),

                  SizedBox(height: 15),

                  // 👤 NAME
                  Text(
                    user.displayName ?? "Người dùng",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: 5),

                  // 📧 EMAIL
                  Text(user.email ?? "", style: TextStyle(color: Colors.grey)),

                  SizedBox(height: 30),

                  Divider(),

                  SizedBox(height: 30),

                  // 🔴 LOGOUT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.logout),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => WelcomeScreen()),
                          (route) => false,
                        );
                      },
                      label: Text("Đăng xuất", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
