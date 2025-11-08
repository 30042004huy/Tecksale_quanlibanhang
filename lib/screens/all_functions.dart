// lib/screens/all_functions.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/features_config.dart'; // 1. Import config (danh sách)
import '../constants/feature_handlers.dart'; // 2. Import handlers (logic onTap)

class AllFunctionsScreen extends StatelessWidget {
  const AllFunctionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tất cả chức năng', style: GoogleFonts.quicksand(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: kAllFeatureItems.length, // Sử dụng danh sách đầy đủ
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 110,
            childAspectRatio: 1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = kAllFeatureItems[index]; // Lấy từ danh sách đầy đủ
            final onTap = kFeatureTapHandlers[item.id] ?? (BuildContext context) {};

            // Sao chép widget _buildFeatureItem từ trang chủ
            return _buildFeatureItem(
              context,
              item.icon,
              item.label,
              item.color,
              onTap,
            );
          },
        ),
      ),
    );
  }

  // Sao chép widget _buildFeatureItem từ trangchu.dart
  Widget _buildFeatureItem(BuildContext context, IconData icon, String label, Color iconColor, Function(BuildContext) onTap) {
    return GestureDetector(
      onTap: () => onTap(context), 
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 18, 32, 45).withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center, 
            ),
          ],
        ),
      ),
    );
  }
}