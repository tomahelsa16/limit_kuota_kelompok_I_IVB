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
  
  // Fitur Translate
  bool isEnglish = false; 

  Timer? _dailyResetTimer;
  String _activeDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Kamus Terjemahan
  final Map<String, Map<String, String>> _localizedValues = {
    'id': {
      'title': 'Monitoring Data',
      'wifi_today': 'WiFi Hari Ini',
      'data_today': 'Data Hari Ini',
      'daily_limit': 'Limit Harian',
      'monthly_limit': 'Limit Bulanan',
      'refresh': 'Refresh Data',
      'set_limit': 'Set Limit Kuota',
      'history': 'Riwayat penggunaan',
      'reached': 'Tercapai!',
      'warning_msg': 'Kuota kamu tinggal 10% lagi!',
      'limit_msg': 'Penggunaan data sudah mencapai limit. Sistem Android tidak mengizinkan aplikasi mematikan internet otomatis. Silakan aktifkan Set Data Limit di pengaturan sistem.',
      'later': 'Nanti',
      'open_settings': 'Buka Pengaturan',
      'save': 'Simpan',
      'cancel': 'Batal',
      'error_input': 'Limit harus berupa angka lebih dari 0.',
      'success_save': 'Limit kuota berhasil disimpan.',
      'permission_title': 'Izin Diperlukan',
      'permission_msg': 'Aplikasi membutuhkan izin Akses Penggunaan untuk membaca statistik data internet di perangkat Anda.',
      'try_again': 'Coba Lagi',
    },
    'en': {
      'title': 'Data Monitoring',
      'wifi_today': 'WiFi Today',
      'data_today': 'Mobile Data Today',
      'daily_limit': 'Daily Limit',
      'monthly_limit': 'Monthly Limit',
      'refresh': 'Refresh Data',
      'set_limit': 'Set Quota Limit',
      'history': 'Usage History',
      'reached': 'Reached!',
      'warning_msg': 'You have only 10% left!',
      'limit_msg': 'Data usage has reached the limit. Android does not allow apps to toggle internet automatically. Please enable Set Data Limit in system settings.',
      'later': 'Later',
      'open_settings': 'Open Settings',
      'save': 'Save',
      'cancel': 'Cancel',
      'error_input': 'Limit must be a number greater than 0.',
      'success_save': 'Quota limit saved successfully.',
      'permission_title': 'Permission Required',
      'permission_msg': 'The app needs Usage Access permission to read internet data statistics on your device.',
      'try_again': 'Try Again',
    }
  };

  String _t(String key) {
    return _localizedValues[isEnglish ? 'en' : 'id']![key] ?? key;
  }

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
    final monthlyLimit = await DatabaseHelper.instance.getSetting(_monthlyLimitKey);

    if (!mounted) return;
    setState(() {
      _dailyLimitBytes = dailyLimit ?? _dailyLimitBytes;
      _monthlyLimitBytes = monthlyLimit ?? _monthlyLimitBytes;
    });
  }

  Future<void> fetchUsage() async {
    await _resetDailyDisplayIfDateChanged();

    try {
      final Map<dynamic, dynamic> result = await platform.invokeMethod('getTodayUsage');

      final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      final wifiBytes = (result['wifi'] as int?) ?? 0;
      final mobileBytes = (result['mobile'] as int?) ?? 0;

      await DatabaseHelper.instance.insertOrUpdate(todayDate, wifiBytes, mobileBytes);
      final monthlyUsage = await DatabaseHelper.instance.getMonthlyUsage(currentMonth);

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
    if (mb > 1024) return "${(mb / 1024).toStringAsFixed(2)} GB";
    return "${mb.toStringAsFixed(2)} MB";
  }

  String _formatLimit(int bytes) {
    return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2);
  }

  int _gbToBytes(double value) => (value * 1024 * 1024 * 1024).round();

  void _checkQuotaLimits() {
    final todayUsage = _todayWifiBytes + _todayMobileBytes;
    _checkSingleLimit(
      title: _t('daily_limit'),
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
      title: _t('monthly_limit'),
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
    if (usageRatio < 0.9) onResetWarning();
    if (usageRatio < 1) onResetLimit();

    if (usageRatio >= 1 && !limitShown) {
      onLimitShown();
      _showLimitReachedDialog(title);
      return;
    }

    if (usageRatio >= 0.9 && !warningShown) {
      onWarningShown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${_t('warning_msg')} $title: ${_formatBytes(currentUsage)} / ${_formatBytes(limitBytes)}."),
        ),
      );
    }
  }

  void _showLimitReachedDialog(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text("$title ${_t('reached')}",
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(_t('limit_msg'),
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('later')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              IntentHelper.openDataLimitSettings();
            },
            child: Text(_t('open_settings')),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetLimitDialog() async {
    final dailyController = TextEditingController(text: _formatLimit(_dailyLimitBytes));
    final monthlyController = TextEditingController(text: _formatLimit(_monthlyLimitBytes));

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(_t('set_limit'),
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dailyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: "${_t('daily_limit')} (GB)"),
            ),
            TextField(
              controller: monthlyController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: "${_t('monthly_limit')} (GB)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final dailyValue = double.tryParse(dailyController.text.replaceAll(',', '.'));
              final monthlyValue = double.tryParse(monthlyController.text.replaceAll(',', '.'));

              if (dailyValue == null || monthlyValue == null || dailyValue <= 0 || monthlyValue <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('error_input'))));
                return;
              }

              await DatabaseHelper.instance.setSetting(_dailyLimitKey, _gbToBytes(dailyValue));
              await DatabaseHelper.instance.setSetting(_monthlyLimitKey, _gbToBytes(monthlyValue));
              if (!context.mounted) return;
              Navigator.pop(context, true);
            },
            child: Text(_t('save')),
          ),
        ],
      ),
    );

    dailyController.dispose();
    monthlyController.dispose();

    if (saved != true || !mounted) return;
    await _loadLimits();
    _dailyWarningShown = _monthlyWarningShown = _dailyLimitShown = _monthlyLimitShown = false;
    _checkQuotaLimits();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('success_save'))));
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(_t('permission_title'), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
        content: Text(_t('permission_msg'), style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              fetchUsage();
            },
            child: Text(_t('try_again')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayUsage = _todayWifiBytes + _todayMobileBytes;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Color.fromARGB(255, 226, 111, 155),
        title: Text(_t('title'), style: const TextStyle(color: Colors.white)),
        actions: [
          Center(
            child: Text(isEnglish ? "EN" : "ID", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Switch(
            value: isEnglish,
            activeColor: Color.fromARGB(255, 44, 35, 38),
            onChanged: (value) => setState(() => isEnglish = value),
          ),
          IconButton(
            tooltip: _t('set_limit'),
            icon: const Icon(Icons.speed, color: Colors.white),
            onPressed: _showSetLimitDialog,
          ),
          IconButton(
            tooltip: _t('history'),
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryPage())),
          ),
          Switch(
            value: isDarkMode,
            activeThumbColor: Colors.white,
            onChanged: (value) => setState(() => isDarkMode = value),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _usageCard(_t('wifi_today'), wifiUsage, Icons.wifi),
              const SizedBox(height: 20),
              _usageCard(_t('data_today'), mobileUsage, Icons.signal_cellular_alt),
              const SizedBox(height: 20),
              _limitInfoCard(_t('daily_limit'), todayUsage, _dailyLimitBytes, Icons.today),
              const SizedBox(height: 20),
              _limitInfoCard(_t('monthly_limit'), _monthlyUsageBytes, _monthlyLimitBytes, Icons.calendar_month),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: fetchUsage,
                icon: const Icon(Icons.refresh),
                label: Text(_t('refresh')),
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
        color: isDarkMode ? Colors.grey[850] : const Color.fromARGB(76, 177, 180, 174),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(width: 3.0, color: isDarkMode ? Colors.white : const Color.fromARGB(255, 226, 111, 155)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: isDarkMode ? Colors.white : const Color.fromARGB(255, 226, 111, 155)),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
              Text(value, style: TextStyle(fontSize: 20, color: isDarkMode ? Colors.white70 : const Color.fromARGB(255, 226, 111, 155))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _limitInfoCard(String title, int currentUsage, int limitBytes, IconData icon) {
    final percent = limitBytes <= 0 ? 0.0 : (currentUsage / limitBytes).clamp(0.0, 1.0);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(width: 2.0, color: isDarkMode ? Colors.white70 : Color.fromARGB(255, 226, 111, 155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isDarkMode ? Colors.white : Color.fromARGB(255, 226, 111, 155)),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: percent),
          const SizedBox(height: 8),
          Text("${_formatBytes(currentUsage)} / ${_formatBytes(limitBytes)}",
            style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ],
      ),
    );
  }
}