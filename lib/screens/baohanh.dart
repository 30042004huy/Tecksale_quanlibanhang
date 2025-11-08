// lib/screens/baohanh.dart
// (TỆP TIN MỚI - GIỮ CHỖ)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BaoHanhScreen extends StatelessWidget {
  const BaoHanhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tra cứu Bảo hành', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue.shade700, // Đồng bộ màu
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_circle_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Đang phát triển',
              style: GoogleFonts.roboto(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Chức năng này sẽ cho phép bạn tra cứu đơn hàng theo SĐT và quản lý bảo hành.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}