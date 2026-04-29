import 'package:flutter/material.dart';

class FullGalleryScreen extends StatelessWidget {
  final List<String> gallery;

  const FullGalleryScreen({super.key, required this.gallery});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thư viện ảnh"), centerTitle: true),
      body: GridView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: gallery.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final imagePath = gallery[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _PreviewScreen(imagePath: imagePath),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Hero(
                tag: imagePath,
                child: Image.asset(
                  imagePath, // ✅ KHÔNG thêm "assets/"
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 40),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreviewScreen extends StatelessWidget {
  final String imagePath;

  const _PreviewScreen({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: imagePath,
          child: InteractiveViewer(
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.broken_image, color: Colors.white);
              },
            ),
          ),
        ),
      ),
    );
  }
}
