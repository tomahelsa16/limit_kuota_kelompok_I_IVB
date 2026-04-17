import 'package:flutter/material.dart';
import 'package:limit_kuota/src/core/data/database_helper.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _historyList;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  void _refreshHistory() {
    setState(() {
      _historyList = DatabaseHelper.instance.getHistory();
    });
  }

  Future<void> _deleteHistoryItem(String date) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Riwayat?"),
        content: Text("Riwayat tanggal $date akan dihapus."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DatabaseHelper.instance.deleteHistoryByDate(date);
    if (!mounted) return;

    _refreshHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Riwayat $date berhasil dihapus.")),
    );
  }

  Future<void> _deleteAllHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Semua Riwayat?"),
        content: const Text("Semua data riwayat penggunaan akan dihapus."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus Semua"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DatabaseHelper.instance.deleteAllHistory();
    if (!mounted) return;

    _refreshHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Semua riwayat berhasil dihapus.")),
    );
  }

  // Helper untuk format bytes (sama seperti di Network page)
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0.00 MB";
    double mb = bytes / (1024 * 1024);
    if (mb > 1024) {
      return "${(mb / 1024).toStringAsFixed(2)} GB";
    }
    return "${mb.toStringAsFixed(2)} MB";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Penggunaan"),
        actions: [
          IconButton(
            tooltip: "Hapus semua riwayat",
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAllHistory,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada riwayat data."));
          }

          final data = snapshot.data!;
          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: Text(
                    item['date'], // Tanggal (YYYY-MM-DD)
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("WiFi: ${_formatBytes(item['wifi'])}"),
                      Text("Mobile: ${_formatBytes(item['mobile'])}"),
                    ],
                  ),
                  trailing: IconButton(
                    tooltip: "Hapus riwayat ini",
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteHistoryItem(item['date']),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
