import 'dart:io';
import 'package:flutter/material.dart';

class FailResultScreen extends StatelessWidget {
  final File? image;

  const FailResultScreen({super.key, this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FB),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Kết quả nhận diện",
          style: TextStyle(color: Colors.black),
        ),
        actions: const [
          Icon(Icons.access_time, color: Colors.black54),
          SizedBox(width: 12),
          Icon(Icons.share, color: Colors.black54),
          SizedBox(width: 12),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 CARD CHÍNH
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                image: DecorationImage(
                  image: AssetImage("assets/images/bannerfail.png"),
                  fit: BoxFit.cover, // 🔥 QUAN TRỌNG
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🔘 BUTTON
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color.fromARGB(255, 92, 232, 229),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Color.fromARGB(255, 139, 243, 161),
                    ),
                    label: const Text(
                      "Chụp lại",
                      style: TextStyle(color: Color.fromARGB(255, 8, 8, 8)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 98, 247, 187),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.photo),
                    label: const Text("Chọn ảnh khác"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // 📍 GỢI Ý
            const Text(
              "✨ Có thể bạn đang tìm?",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 6),

            const Text(
              "Dưới đây là một số địa điểm phổ biến",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _place(
                    "Cầu Vàng",
                    "Đà Nẵng",
                    "assets/images/cau_vang.jpg",
                    "12 km",
                  ),
                  _place(
                    "Phố cổ Hội An",
                    "Quảng Nam",
                    "assets/images/pho_co_hoi_an.jpg",
                    "35 km",
                  ),
                  _place(
                    "Vịnh Hạ Long",
                    "Quảng Ninh",
                    "assets/images/vinh_ha_long.jpg",
                    "230 km",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // 📍 CARD ĐỊA ĐIỂM
  Widget _place(String name, String location, String img, String distance) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              img,
              height: 90,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            location,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 12,
                color: Color.fromARGB(255, 67, 219, 242),
              ),
              Text(
                " $distance",
                style: const TextStyle(
                  fontSize: 12,
                  color: Color.fromARGB(255, 110, 232, 163),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
