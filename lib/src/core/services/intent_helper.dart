import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'dart:io';

class IntentHelper {
  static Future<void> openDataLimitSettings() async {
    if (Platform.isAndroid) {
      // Intent ini mengarahkan langsung ke pengaturan penggunaan data
      const intent = AndroidIntent(
        action: 'android.settings.DATA_USAGE_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      
      try {
        await intent.launch();
      } catch (e) {
        print("Gagal membuka pengaturan: $e");
        // Jika gagal ke halaman spesifik, buka pengaturan umum
        const fallbackIntent = AndroidIntent(
          action: 'android.settings.SETTINGS',
        );
        await fallbackIntent.launch();
      }
    }
  }
}
