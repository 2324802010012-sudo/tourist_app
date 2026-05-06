import 'package:flutter/material.dart';
import '../services/history_service.dart';
import 'detail_screen.dart';
import '../models/location_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List historyList = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  void loadHistory() async {
    final data = await HistoryService.getHistory();
    setState(() {
      historyList = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Lịch sử"),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () async {
              await HistoryService.clearHistory();
              loadHistory();
            },
          ),
        ],
      ),
      body: historyList.isEmpty
          ? Center(child: Text("Chưa có lịch sử"))
          : ListView.builder(
              padding: EdgeInsets.all(12),
              itemCount: historyList.length,
              itemBuilder: (context, index) {
                final item = historyList[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DetailScreen(data: Location.fromJson(item)),
                      ),
                    ).then((_) => loadHistory());
                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 5),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            "assets/${item['thumbnail_url']}",
                            width: 80,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['location_name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                item['province'],
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await HistoryService.removeHistory(
                              item['location_name'],
                            );
                            loadHistory();
                          },
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
