import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:tourist_app/screens/auth/welcome_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/favorite_screen.dart';
import 'screens/history_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/detail_screen.dart';
import 'models/location_model.dart';
import 'package:tourist_app/screens/auth/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tourist App',
      home: WelcomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List locations = []; // dữ liệu gốc JSON
  List filteredLocations = []; // dữ liệu sau khi search
  bool isLoading = true;
  bool isSearching = false;
  @override
  void initState() {
    super.initState();
    loadData();
  }

  // 🔥 LOAD DATA
  Future<void> loadData() async {
    try {
      String jsonString = await rootBundle.loadString(
        'assets/data/locations.json',
      );

      final data = json.decode(jsonString);

      setState(() {
        locations = data;
        filteredLocations = data; // 🔥 QUAN TRỌNG
        isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Lỗi JSON: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // 🔥 SEARCH
  void search(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        filteredLocations = locations;
        isSearching = false;
      });
      return;
    }

    final key = keyword.toLowerCase();

    final result = locations.where((item) {
      final name = item['location_name'].toString().toLowerCase();
      final province = item['province'].toString().toLowerCase();
      final address = item['address'].toString().toLowerCase();

      return name.contains(key) ||
          province.contains(key) ||
          address.contains(key);
    }).toList();

    setState(() {
      filteredLocations = result;
      isSearching = true;
    });
  }

  void showLoginDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Cần đăng nhập"),
        content: Text("Bạn cần đăng nhập để dùng chức năng này."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Để sau"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
            child: Text("Đăng nhập"),
          ),
        ],
      ),
    );
  }

  void handleTopButtonClick(String text) {
    if (text == "Quét AI") {
      // ✅ Cho dùng luôn
      Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen()));
    } else {
      // ❌ Bắt đăng nhập
      if (FirebaseAuth.instance.currentUser == null) {
        showLoginDialog();
      } else {
        if (text == "Yêu thích") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FavoriteScreen()),
          );
        } else if (text == "Lịch sử") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HistoryScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔍 SEARCH + USER
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: search,
                              decoration: InputDecoration(
                                hintText: "Tìm kiếm địa điểm...",
                                prefixIcon: Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 10),

                          GestureDetector(
                            onTap: () {
                              if (FirebaseAuth.instance.currentUser == null) {
                                showLoginDialog();
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(),
                                  ),
                                );
                              }
                            },
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Color(0xFF2F80ED),
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10),

                    // 🔥 SEARCH RESULT
                    if (isSearching) ...[
                      if (filteredLocations.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text("Không tìm thấy")),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: filteredLocations.length,
                          itemBuilder: (context, index) {
                            var item = filteredLocations[index];

                            return ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailScreen(
                                      data: Location.fromJson(
                                        Map<String, dynamic>.from(item),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/${item['thumbnail_url']}',
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(item['location_name']),
                              subtitle: Text(item['province']),
                              trailing: const Icon(Icons.chevron_right),
                            );
                          },
                        ),
                    ],

                    // 🔥 UI CHỈ HIỆN KHI KHÔNG SEARCH
                    if (!isSearching) ...[
                      // 🖼️ BANNER
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/banner.png',
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      SizedBox(height: 14),
                      // ⚡ BUTTON (YÊU THÍCH - LỊCH SỬ - QUÉT AI)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            buildTopButton(Icons.favorite_border, "Yêu thích"),
                            buildTopButton(Icons.history, "Lịch sử"),
                            buildTopButton(Icons.qr_code_scanner, "Quét AI"),
                          ],
                        ),
                      ),

                      SizedBox(height: 20),
                      // 🌍 ĐỊA ĐIỂM NỔI BẬT
                      sectionTitle("Địa điểm nổi bật"),

                      SizedBox(height: 10),

                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: locations.length,
                          itemBuilder: (context, index) {
                            var item = locations[index];

                            return Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundImage: AssetImage(
                                      'assets/${item['thumbnail_url']}',
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    item['location_name'],
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 20),

                      // 🎬 VIDEO
                      sectionTitle("Video giới thiệu"),

                      SizedBox(height: 10),

                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: locations.length,
                          itemBuilder: (context, index) {
                            var item = locations[index];

                            return Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: GestureDetector(
                                onTap: () {
                                  String videoPath =
                                      'assets/${item['video_url']}';

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VideoScreen(
                                        videoPath: videoPath,
                                        title: item['location_name'],
                                      ),
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width: 160,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/${item['thumbnail_url']}',
                                              height: 100,
                                              width: 160,
                                              fit: BoxFit.cover,
                                            ),
                                            Icon(
                                              Icons.play_circle_fill,
                                              size: 40,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        item['location_name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        item['province'],
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget buildTopButton(IconData icon, String text) {
    return Expanded(
      child: GestureDetector(
        onTap: () => handleTopButtonClick(text),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 24),
            ),
            SizedBox(height: 6),
            Text(text, style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Icon(Icons.arrow_forward_ios, size: 14),
        ],
      ),
    );
  }
}

class VideoScreen extends StatefulWidget {
  final String videoPath;
  final String title;

  const VideoScreen({super.key, required this.videoPath, required this.title});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset(widget.videoPath);

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _controller.setLooping(true);

        // fix blur frame đầu
        _controller.play();
        _controller.pause();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 247, 245, 245),

      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 240, 239, 239),
        title: Text(widget.title),
      ),

      body: Center(
        child: _controller.value.isInitialized
            ? Stack(
                alignment: Alignment.center,
                children: [
                  // 🎥 VIDEO
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),

                  // ▶️ NÚT PLAY (CHỈ HIỆN KHI PAUSE)
                  if (!_controller.value.isPlaying)
                    GestureDetector(
                      onTap: togglePlay,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(115, 246, 243, 243),
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.play_arrow,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // ⏸️ TAP VIDEO ĐỂ PAUSE
                  if (_controller.value.isPlaying)
                    GestureDetector(
                      onTap: togglePlay,
                      child: Container(color: Colors.transparent),
                    ),
                ],
              )
            : CircularProgressIndicator(),
      ),
    );
  }
}
