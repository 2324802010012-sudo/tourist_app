import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/favorite_service.dart';
import '../models/location_model.dart';
import 'detail_screen.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  List<Location> favoriteList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  // 🔥 LOAD DATA THẬT (ANTI LỖI)
  void loadFavorites() async {
    var all = await LocationService.loadLocations();
    var favIds = await FavoriteService.getFavorites();

    setState(() {
      favoriteList = all.where((loc) {
        return favIds.any(
          (id) =>
              id.toLowerCase().trim() ==
              loc.predictedLabel.toLowerCase().trim(),
        );
      }).toList();

      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),

      appBar: AppBar(title: Text("Yêu thích"), centerTitle: true),

      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : favoriteList.isEmpty
          ? Center(
              child: Text(
                "Chưa có địa điểm yêu thích ❤️",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: favoriteList.length,
              itemBuilder: (_, i) {
                var loc = favoriteList[i];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(data: loc),
                      ),
                    ).then((_) {
                      loadFavorites(); // 🔄 reload
                    });
                  },

                  child: Container(
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),

                    child: Row(
                      children: [
                        // 🖼 IMAGE
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            loc.thumbnail,
                            width: 120,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),

                        // 📄 CONTENT
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        loc.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.favorite, color: Colors.red),
                                  ],
                                ),

                                SizedBox(height: 4),

                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      loc.province,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 6),

                                Text(
                                  loc.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
