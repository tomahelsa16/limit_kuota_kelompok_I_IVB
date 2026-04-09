import 'package:flutter/material.dart';
import 'package:limit_kuota/src/features/monitoring/network_page.dart';

void main() {
  // Jalankan MyApp, bukan langsung Network
  runApp(const MyApp()); 
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false, // Opsional: hilangkan banner debug
      home: Network(), // Network sekarang punya akses ke Directionality dari MaterialApp
    );
  }
}
