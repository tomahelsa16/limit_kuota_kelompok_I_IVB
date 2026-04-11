import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:limit_kuota/src/core/data/database_helper.dart';
import 'package:limit_kuota/src/core/services/intent_helper.dart';
import 'package:limit_kuota/src/features/monitoring/history_page.dart';

class Network extends StatefulWidget {
  const Network({super.key});

  @override
  State<Network> createState() => _NetworkState();
}

class _NetworkState extends State<Network> {
  static const platform = MethodChannel('limit_kuota/channel');

  String wifiUsage = "0.00 MB";
  String mobileUsage = "0.00 MB";

  // ✅ DARK MODE STATE
  bool isDarkMode = false;

  Future<void> fetchUsage() async {
    try {
      final Map<dynamic, dynamic> result = await platform.invokeMethod(
        'getTodayUsage',
      );

      String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      int wifiBytes = result['wifi'] ?? 0;
      int mobileBytes = result['mobile'] ?? 0;

      await DatabaseHelper.instance.insertOrUpdate(
        todayDate,
        wifiBytes,
        mobileBytes,
      );

      setState(() {
        wifiUsage = _formatBytes(result['wifi']);
        mobileUsage = _formatBytes(result['mobile']);
      });
    } on PlatformException catch (e) {
      if (e.code == "PERMISSION_DENIED") {
        _showPermissionDialog();
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0.00 MB";
    double mb = bytes / (1024 * 1024);
    if (mb > 1024) {
      return "${(mb / 1024).toStringAsFixed(2)} GB";
    }
    return "${mb.toStringAsFixed(2)} MB";
  }

  Future<void> checkLimitAndWarn(int currentUsage) async {
    int limitInBytes = 1024 * 1024 * 1024;

    if (currentUsage >= limitInBytes) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            "Batas Kuota Tercapai!",
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          content: Text(
            "Penggunaan data Anda sudah mencapai mencapai limit. "
            "Sistem Android tidak mengizinkan aplikasi mematikan internet secara otomatis. "
            "Silakan aktifkan 'Set Data Limit' di pengaturan sistem agar koneksi terputus otomatis.",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Nanti"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                IntentHelper.openDataLimitSettings();
              },
              child: const Text("Buka Pengaturan"),
            ),
          ],
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUsage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color.fromARGB(255, 0, 0, 0)
            : Colors.blue,
        // ✅ Perubahan: Judul berubah putih saat dark mode
        title: Text(
          'Monitoring Data',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),
          // ✅ SWITCH DARK MODE
          Switch(
            value: isDarkMode,
            activeColor: Colors.white,
            onChanged: (value) {
              setState(() {
                isDarkMode = value;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _usageCard("WiFi Hari Ini", wifiUsage, Icons.wifi),
            const SizedBox(height: 20),
            _usageCard("Data Hari Ini", mobileUsage, Icons.signal_cellular_alt),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: fetchUsage,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _usageCard(String title, String value, IconData icon) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey[850]
            : const Color.fromARGB(76, 177, 180, 174),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          // ✅ Perubahan: Border dibuat lebih tebal (width: 3)
          width: 3.0, 
          color: isDarkMode
              ? Colors.white
              : const Color.fromARGB(255, 226, 111, 155),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 40,
            color: isDarkMode
                ? Colors.white
                : const Color.fromARGB(255, 226, 111, 155),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  color: isDarkMode
                      ? Colors.white70
                      : const Color.fromARGB(255, 226, 111, 155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            "Izin Diperlukan",
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          ),
          content: Text(
            "Aplikasi membutuhkan izin 'Akses Penggunaan' untuk membaca statistik data internet di perangkat Anda.\n\n"
            "Silakan aktifkan izin untuk aplikasi ini di halaman pengaturan yang akan terbuka.",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                fetchUsage();
              },
              child: const Text("Buka Pengaturan"),
            ),
          ],
        );
      },
    );
  }
}