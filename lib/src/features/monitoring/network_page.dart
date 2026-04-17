import 'dart:async';

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
  static const _dailyLimitKey = 'daily_limit_bytes';
  static const _monthlyLimitKey = 'monthly_limit_bytes';

  String wifiUsage = "0.00 MB";
  String mobileUsage = "0.00 MB";

  int _todayWifiBytes = 0;
  int _todayMobileBytes = 0;
  int _monthlyUsageBytes = 0;
  int _dailyLimitBytes = 1024 * 1024 * 1024;
  int _monthlyLimitBytes = 30 * 1024 * 1024 * 1024;

  bool _dailyWarningShown = false;
  bool _monthlyWarningShown = false;
  bool _dailyLimitShown = false;
  bool _monthlyLimitShown = false;
  bool isDarkMode = false;

  Timer? _dailyResetTimer;
  String _activeDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _initializeUsage();
    _scheduleDailyReset();
  }

  @override
  void dispose() {
    _dailyResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeUsage() async {
    await _loadLimits();
    await fetchUsage();
  }

  Future<void> _loadLimits() async {
    final dailyLimit = await DatabaseHelper.instance.getSetting(_dailyLimitKey);
    final monthlyLimit = await DatabaseHelper.instance.getSetting(
      _monthlyLimitKey,
    );

    if (!mounted) return;
    setState(() {
      _dailyLimitBytes = dailyLimit ?? _dailyLimitBytes;
      _monthlyLimitBytes = monthlyLimit ?? _monthlyLimitBytes;
    });
  }

  Future<void> fetchUsage() async {
    await _resetDailyDisplayIfDateChanged();

    try {
      final Map<dynamic, dynamic> result = await platform.invokeMethod(
        'getTodayUsage',
      );

      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      final wifiBytes = (result['wifi'] as int?) ?? 0;
      final mobileBytes = (result['mobile'] as int?) ?? 0;

      await DatabaseHelper.instance.insertOrUpdate(
        todayDate,
        wifiBytes,
        mobileBytes,
      );
      final monthlyUsage = await DatabaseHelper.instance.getMonthlyUsage(
        currentMonth,
      );

      if (!mounted) return;
      setState(() {
        _activeDate = todayDate;
        _todayWifiBytes = wifiBytes;
        _todayMobileBytes = mobileBytes;
        _monthlyUsageBytes = monthlyUsage;
        wifiUsage = _formatBytes(wifiBytes);
        mobileUsage = _formatBytes(mobileBytes);
      });

      _checkQuotaLimits();
    } on PlatformException catch (e) {
      if (e.code == "PERMISSION_DENIED") {
        _showPermissionDialog();
      }
    }
  }

  Future<void> _resetDailyDisplayIfDateChanged() async {
    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_activeDate == todayDate) return;

    await DatabaseHelper.instance.insertOrUpdate(todayDate, 0, 0);
    if (!mounted) return;

    setState(() {
      _activeDate = todayDate;
      _todayWifiBytes = 0;
      _todayMobileBytes = 0;
      wifiUsage = "0.00 MB";
      mobileUsage = "0.00 MB";
      _dailyWarningShown = false;
      _dailyLimitShown = false;
    });
  }

  void _scheduleDailyReset() {
    _dailyResetTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _dailyResetTimer = Timer(nextMidnight.difference(now), () async {
      await _resetDailyDisplayIfDateChanged();
      await fetchUsage();
      _scheduleDailyReset();
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0.00 MB";
    final mb = bytes / (1024 * 1024);
    if (mb > 1024) {
      return "${(mb / 1024).toStringAsFixed(2)} GB";
    }
    return "${mb.toStringAsFixed(2)} MB";
  }

  String _formatLimit(int bytes) {
    return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
  }

  int _gbToBytes(double value) {
    return (value * 1024 * 1024 * 1024).round();
  }

  void _checkQuotaLimits() {
    final todayUsage = _todayWifiBytes + _todayMobileBytes;
    _checkSingleLimit(
      title: "Limit Harian",
      currentUsage: todayUsage,
      limitBytes: _dailyLimitBytes,
      warningShown: _dailyWarningShown,
      limitShown: _dailyLimitShown,
      onWarningShown: () => _dailyWarningShown = true,
      onLimitShown: () => _dailyLimitShown = true,
      onResetWarning: () => _dailyWarningShown = false,
      onResetLimit: () => _dailyLimitShown = false,
    );

    _checkSingleLimit(
      title: "Limit Bulanan",
      currentUsage: _monthlyUsageBytes,
      limitBytes: _monthlyLimitBytes,
      warningShown: _monthlyWarningShown,
      limitShown: _monthlyLimitShown,
      onWarningShown: () => _monthlyWarningShown = true,
      onLimitShown: () => _monthlyLimitShown = true,
      onResetWarning: () => _monthlyWarningShown = false,
      onResetLimit: () => _monthlyLimitShown = false,
    );
  }

  void _checkSingleLimit({
    required String title,
    required int currentUsage,
    required int limitBytes,
    required bool warningShown,
    required bool limitShown,
    required VoidCallback onWarningShown,
    required VoidCallback onLimitShown,
    required VoidCallback onResetWarning,
    required VoidCallback onResetLimit,
  }) {
    if (limitBytes <= 0 || !mounted) return;

    final usageRatio = currentUsage / limitBytes;
    if (usageRatio < 0.9) {
      onResetWarning();
    }
    if (usageRatio < 1) {
      onResetLimit();
    }

    if (usageRatio >= 1 && !limitShown) {
      onLimitShown();
      _showLimitReachedDialog(title);
      return;
    }

    if (usageRatio >= 0.9 && !warningShown) {
      onWarningShown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Kuota kamu tinggal 10% lagi! $title: ${_formatBytes(currentUsage)} dari ${_formatBytes(limitBytes)}.",
          ),
        ),
      );
    }
  }

  void _showLimitReachedDialog(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          "$title Tercapai!",
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          "Penggunaan data sudah mencapai limit. Sistem Android tidak mengizinkan aplikasi mematikan internet otomatis. Silakan aktifkan Set Data Limit di pengaturan sistem.",
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
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

  Future<void> _showSetLimitDialog() async {
    final dailyController = TextEditingController(
      text: _formatLimit(_dailyLimitBytes),
    );
    final monthlyController = TextEditingController(
      text: _formatLimit(_monthlyLimitBytes),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          "Set Limit Kuota",
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dailyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "Limit harian (GB)",
                hintText: "Contoh: 1.5",
              ),
            ),
            TextField(
              controller: monthlyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "Limit bulanan (GB)",
                hintText: "Contoh: 30",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              final dailyValue = double.tryParse(
                dailyController.text.replaceAll(',', '.'),
              );
              final monthlyValue = double.tryParse(
                monthlyController.text.replaceAll(',', '.'),
              );

              if (dailyValue == null ||
                  monthlyValue == null ||
                  dailyValue <= 0 ||
                  monthlyValue <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Limit harus berupa angka lebih dari 0."),
                  ),
                );
                return;
              }

              final dailyBytes = _gbToBytes(dailyValue);
              final monthlyBytes = _gbToBytes(monthlyValue);
              await DatabaseHelper.instance.setSetting(
                _dailyLimitKey,
                dailyBytes,
              );
              await DatabaseHelper.instance.setSetting(
                _monthlyLimitKey,
                monthlyBytes,
              );

              if (!context.mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );

    dailyController.dispose();
    monthlyController.dispose();

    if (saved != true || !mounted) return;

    await _loadLimits();
    _dailyWarningShown = false;
    _monthlyWarningShown = false;
    _dailyLimitShown = false;
    _monthlyLimitShown = false;
    _checkQuotaLimits();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Limit kuota berhasil disimpan.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayUsage = _todayWifiBytes + _todayMobileBytes;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color.fromARGB(255, 0, 0, 0)
            : Colors.blue,
        title: const Text(
          'Monitoring Data',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: "Set limit kuota",
            icon: const Icon(Icons.speed, color: Colors.white),
            onPressed: _showSetLimitDialog,
          ),
          IconButton(
            tooltip: "Riwayat penggunaan",
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),
          Switch(
            value: isDarkMode,
            activeThumbColor: Colors.white,
            onChanged: (value) {
              setState(() {
                isDarkMode = value;
              });
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _usageCard("WiFi Hari Ini", wifiUsage, Icons.wifi),
              const SizedBox(height: 20),
              _usageCard(
                "Data Hari Ini",
                mobileUsage,
                Icons.signal_cellular_alt,
              ),
              const SizedBox(height: 20),
              _limitInfoCard(
                "Limit Harian",
                todayUsage,
                _dailyLimitBytes,
                Icons.today,
              ),
              const SizedBox(height: 20),
              _limitInfoCard(
                "Limit Bulanan",
                _monthlyUsageBytes,
                _monthlyLimitBytes,
                Icons.calendar_month,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: fetchUsage,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Data'),
              ),
            ],
          ),
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

  Widget _limitInfoCard(
    String title,
    int currentUsage,
    int limitBytes,
    IconData icon,
  ) {
    final percent = limitBytes <= 0
        ? 0.0
        : (currentUsage / limitBytes).clamp(0.0, 1.0);

    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          width: 2.0,
          color: isDarkMode ? Colors.white70 : Colors.blue,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDarkMode ? Colors.white : Colors.blue),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: percent),
          const SizedBox(height: 8),
          Text(
            "${_formatBytes(currentUsage)} / ${_formatBytes(limitBytes)}",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
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
            "Aplikasi membutuhkan izin Akses Penggunaan untuk membaca statistik data internet di perangkat Anda.\n\nSilakan aktifkan izin untuk aplikasi ini di halaman pengaturan yang terbuka.",
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
              child: const Text("Coba Lagi"),
            ),
          ],
        );
      },
    );
  }
}
