import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/location_model.dart';
import '../services/location_discovery_service.dart';
import '../services/location_service.dart';
import '../services/travel_preference_service.dart';
import 'auth/welcome_screen.dart';
import 'detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameController = TextEditingController();
  final Set<String> selectedPreferences = {};
  List<Location> allLocations = [];
  List<Location> recommendationPreview = [];
  bool isSaving = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final savedPreferences = await TravelPreferenceService.load();
    final locations = await LocationService.loadLocations();

    if (!mounted) return;
    setState(() {
      nameController.text = user?.displayName ?? "";
      allLocations = locations;
      selectedPreferences
        ..clear()
        ..addAll(savedPreferences);
      recommendationPreview = LocationDiscoveryService.recommendedLocations(
        allLocations,
        selectedPreferences,
        limit: 3,
      );
      isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final name = nameController.text.trim();

    if (user == null) return;
    if (name.isEmpty) {
      _showSnackBar("Họ tên không được để trống.");
      return;
    }

    setState(() => isSaving = true);
    try {
      await user.updateDisplayName(name);
      await user.reload();
      await TravelPreferenceService.save(selectedPreferences);

      if (!mounted) return;
      _showSnackBar("Đã cập nhật hồ sơ và gu du lịch.");
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Không lưu được hồ sơ. Vui lòng thử lại.");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Đăng xuất tài khoản"),
        content: const Text("Bạn có chắc muốn kết thúc phiên đăng nhập?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Đăng xuất"),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Tài khoản"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text("Chưa đăng nhập"))
          : isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _profileHeader(user),
                const SizedBox(height: 16),
                _editCard(user),
                const SizedBox(height: 16),
                _preferenceCard(),
                const SizedBox(height: 16),
                _recommendationCard(),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2FAE66),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isSaving ? null : _saveProfile,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(isSaving ? "Đang lưu..." : "Lưu hồ sơ"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text("Đăng xuất"),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _profileHeader(User user) {
    final displayName = nameController.text.trim().isEmpty
        ? "Người dùng"
        : nameController.text.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2FAE66), Color(0xFF27C6DA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              displayName.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editCard(User user) {
    return _card(
      title: "Thông tin cá nhân",
      icon: Icons.badge,
      child: Column(
        children: [
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: "Họ và tên",
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: false,
            controller: TextEditingController(text: user.email ?? ""),
            decoration: const InputDecoration(
              labelText: "Email",
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferenceCard() {
    return _card(
      title: "Sở thích du lịch",
      icon: Icons.explore,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectedPreferences.isEmpty
                ? "Chọn gu để trang chủ ưu tiên địa điểm phù hợp."
                : "Đã chọn ${selectedPreferences.length} gu du lịch.",
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TravelPreferenceService.options.map((item) {
              final selected = selectedPreferences.contains(item);
              return FilterChip(
                avatar: Icon(
                  _preferenceIcon(item),
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF1F8A56),
                ),
                label: Text(item),
                selected: selected,
                checkmarkColor: Colors.white,
                selectedColor: const Color(0xFF1F8A56),
                backgroundColor: const Color(0xFFF2F7F1),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (value) {
                  setState(() {
                    value
                        ? selectedPreferences.add(item)
                        : selectedPreferences.remove(item);
                    recommendationPreview =
                        LocationDiscoveryService.recommendedLocations(
                          allLocations,
                          selectedPreferences,
                          limit: 3,
                        );
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _recommendationCard() {
    return _card(
      title: "Gợi ý hợp gu",
      icon: Icons.auto_awesome,
      child: recommendationPreview.isEmpty
          ? const Text(
              "Chưa có dữ liệu địa điểm để tạo gợi ý.",
              style: TextStyle(color: Colors.black54),
            )
          : Column(
              children: recommendationPreview.map((location) {
                final reasons = LocationDiscoveryService.matchReasons(
                  location,
                  selectedPreferences,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(data: location),
                        ),
                      );
                    },
                    child: Ink(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0ECE4)),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              location.thumbnail,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  location.province,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                if (reasons.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    reasons.join(" • "),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF1F8A56),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2FAE66)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  IconData _preferenceIcon(String preference) {
    return switch (preference) {
      "Di sản lịch sử" => Icons.account_balance,
      "Thiên nhiên" => Icons.landscape,
      "Check-in" => Icons.photo_camera,
      "Ẩm thực" => Icons.restaurant,
      "Gia đình" => Icons.family_restroom,
      "Trải nghiệm tiết kiệm" => Icons.savings,
      _ => Icons.explore,
    };
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
