import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'full_gallery_screen.dart';
import 'dart:ui';
import '../services/favorite_service.dart';
import '../models/location_model.dart';

// 🎨 THEME
const primaryGradient = LinearGradient(
  colors: [
    Color.fromARGB(255, 72, 215, 132),
    Color.fromARGB(255, 61, 186, 244),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const primaryColor = Color(0xFF7B61FF);
const softBg = Color(0xFFF5F6FA);

class DetailScreen extends StatefulWidget {
  final Location data;

  const DetailScreen({super.key, required this.data});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  VideoPlayerController? _controller;
  int currentIndex = 0;
  bool isFav = false;
  @override
  void initState() {
    super.initState();

    loadFavorite(); // 🔥 THÊM

    String video = widget.data.videoUrl;

    if (video.isNotEmpty) {
      _controller = VideoPlayerController.asset("assets/" + video)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _controller!.setLooping(true);
            _controller!.play();
          }
        });
    }
  }

  void loadFavorite() async {
    String id = widget.data.predictedLabel;

    bool fav = await FavoriteService.isFavorite(id);

    if (mounted) {
      setState(() {
        isFav = fav;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    List<String> gallery = [data.thumbnail, ...?data.gallery];
    double confidence = 0.91;

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: Text("Kết quả nhận diện"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(Icons.favorite, color: isFav ? Colors.red : Colors.grey),
            onPressed: () async {
              String id = widget.data.predictedLabel;

              await FavoriteService.toggleFavorite(id);

              setState(() {
                isFav = !isFav;
              });
            },
          ),
          SizedBox(width: 10),
          Icon(Icons.share),
          SizedBox(width: 10),
        ],
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🎬 VIDEO / IMAGE
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  _controller != null && _controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : Image.asset(
                          gallery[currentIndex],
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),

                  // ▶ play icon
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: AnimatedOpacity(
                        duration: Duration(milliseconds: 300),
                        opacity:
                            (_controller != null &&
                                _controller!.value.isPlaying)
                            ? 0 // 👉 đang chạy → ẩn
                            : 1, // 👉 pause → hiện

                        child: GestureDetector(
                          onTap: () {
                            if (_controller != null &&
                                _controller!.value.isInitialized) {
                              if (_controller!.value.isPlaying) {
                                _controller!.pause();
                              } else {
                                _controller!.play();
                              }
                              setState(() {});
                            }
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                              ),
                              color: Colors.white.withOpacity(0.15),
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 🔥 badge auto play
                ],
              ),
            ),

            SizedBox(height: 15),

            // TITLE + CONFIDENCE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data.name,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                ),

                // 🔥 GRADIENT BOX
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Độ chính xác",
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      Text(
                        "${(confidence * 100).toStringAsFixed(1)}%",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 6),

            Text("📍 ${data.address}", style: TextStyle(color: Colors.grey)),

            SizedBox(height: 15),

            Text(data.description),

            SizedBox(height: 20),

            // 🔥 ACTION CARD
            Container(
              padding: EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _action(
                    Icons.favorite,
                    "Yêu thích",
                    isFav ? Colors.red : Colors.pink,
                    () async {
                      String id = widget.data.predictedLabel;
                      if (id.isEmpty) return;

                      await FavoriteService.toggleFavorite(id);

                      setState(() {
                        isFav = !isFav;
                      });
                    },
                  ),

                  _action(Icons.map, "Bản đồ", Colors.blue, null),
                  _action(Icons.play_circle, "Video", Colors.deepPurple, null),
                  _action(Icons.share, "Chia sẻ", Colors.green, null),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 📊 INFO CARD
            Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _infoItem(
                      Icons.location_on,
                      "Địa điểm",
                      data.province,
                      Colors.purple,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _infoItem(
                      Icons.access_time,
                      "Giờ mở cửa",
                      data.openingHours,
                      Colors.green,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _infoItem(
                      Icons.confirmation_num,
                      "Giá vé",
                      data.ticketPrice,
                      Colors.orange,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _infoItem(
                      Icons.star,
                      "Đánh giá",
                      "4.8/5",
                      Colors.amber,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 🖼️ GALLERY
            // 🖼️ GALLERY
            Column(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        gallery[currentIndex],
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                    // ✅ ĐÚNG: nằm trong Stack
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${currentIndex + 1}/${gallery.length}",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),

                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: gallery.length > 4 ? 5 : gallery.length,
                    itemBuilder: (context, index) {
                      if (index == 4 && gallery.length > 5) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    FullGalleryScreen(gallery: gallery),
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: 8),
                            width: 80,
                            decoration: BoxDecoration(
                              gradient: primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "+${gallery.length - 4}\nXem thêm",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      }

                      return GestureDetector(
                        onTap: () {
                          setState(() => currentIndex = index);
                        },
                        child: _thumb(gallery[index]),
                      );
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 30),

            // 🔘 BUTTON
            SizedBox(
              width: double.infinity,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => Navigator.pop(context),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 94, 248, 132),
                        Color.fromARGB(255, 80, 191, 246),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 20),

                        SizedBox(width: 8),

                        Text(
                          "Chụp lại",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String text, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 60, // 👉 tăng lên
      width: 1,
      color: Colors.grey[300],
    );
  }

  Widget _infoItem(IconData icon, String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(height: 6),

        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey)),

        SizedBox(height: 4),

        Text(
          value,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // THUMB
  Widget _thumb(String path) {
    return Container(
      margin: EdgeInsets.only(right: 10), // 👉 tăng spacing
      width: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
      ),
    );
  }
}
