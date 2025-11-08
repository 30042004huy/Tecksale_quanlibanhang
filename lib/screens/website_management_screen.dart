// lib/screens/website_management_screen.dart
// (ĐÃ THIẾT KẾ LẠI + THÊM CHỨC NĂNG MỚI)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'website_products_screen.dart'; 
import 'website_orders_screen.dart';
import 'thongtinwebsite.dart'; // ✨ MỤC MỚI
import 'baivietwebsite.dart';  // ✨ MỤC MỚI
import 'baohanh.dart';           // ✨ MỤC MỚI
import '../constants/admin_config.dart';

// Lớp để định nghĩa 1 chức năng
class ManagementItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget targetScreen;

  ManagementItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.targetScreen,
  });
}

class WebsiteManagementScreen extends StatelessWidget {
  const WebsiteManagementScreen({super.key});

@override
  Widget build(BuildContext context) {
    // ✨ 2. THÊM LỚP KIỂM TRA BẢO VỆ
    if (!AdminService.isCurrentUserAdmin()) {
      // Dùng WidgetsBinding để pop (đóng) màn hình này một cách an toàn
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
          // Gửi thêm thông báo (không bắt buộc, vì file handler đã báo rồi)
        }
      });
      
      // Trả về một màn hình trống rỗng trong khi chờ pop
      return const Scaffold(
        backgroundColor: Colors.grey,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // ✨ DANH SÁCH CHỨC NĂNG MỚI
    final List<ManagementItem> items = [
      ManagementItem(
        id: 'shop_info',
        title: 'Thông tin Shop',
        subtitle: 'Logo, SĐT, Facebook, Zalo...',
        icon: Icons.store_mall_directory,
        color: const Color(0xFF1E88E5), // Blue
        targetScreen: const ThongTinWebsiteScreen(),
      ),
      ManagementItem(
        id: 'products',
        title: 'Sản phẩm',
        subtitle: 'Quản lý sản phẩm hiển thị',
        icon: Icons.storefront,
        color: const Color(0xFF43A047), // Green
        targetScreen: const WebsiteProductsScreen(),
      ),
      ManagementItem(
        id: 'orders',
        title: 'Đơn hàng',
        subtitle: 'Đơn hàng từ khách vãng lai',
        icon: Icons.receipt_long,
        color: const Color(0xFFE53935), // Red
        targetScreen: const WebsiteOrdersScreen(),
      ),
      ManagementItem(
        id: 'blog',
        title: 'Bài viết SEO',
        subtitle: 'Viết bài blog, tin tức',
        icon: Icons.article,
        color: const Color(0xFFF9A825), // Yellow
        targetScreen: const BaiVietWebsiteScreen(),
      ),
      ManagementItem(
        id: 'warranty',
        title: 'Tra cứu Bảo hành',
        subtitle: 'Quản lý đơn hàng bảo hành',
        icon: Icons.build_circle_outlined,
        color: const Color(0xFF8E24AA), // Purple
        targetScreen: const BaoHanhScreen(),
      ),
      ManagementItem(
        id: 'theme',
        title: 'Giao diện',
        subtitle: 'Đổi màu sắc, banner (Tương lai)',
        icon: Icons.palette,
        color: const Color(0xFF00897B), // Teal
        targetScreen: const Scaffold(body: Center(child: Text("Đang phát triển"))),
      ),
    ];

    return Scaffold(
      // ✨ YÊU CẦU: AppBar đồng bộ
      appBar: AppBar(
        title: Text(
          'Quản lý Website',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold,
            color: Colors.white, // Chữ trắng
          ),
        ),
        backgroundColor: Colors.blue.shade700, // Màu xanh dương
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(25), // Bo tròn đẹp
          ),
        ),
      ),
      backgroundColor: Colors.grey.shade100,
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 cột
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9, // Điều chỉnh tỷ lệ
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildManagementCard(
            context: context,
            item: item,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => item.targetScreen),
              );
            },
          );
        },
      ),
    );
  }

  // ✨ YÊU CẦU: Widget được thiết kế lại
  Widget _buildManagementCard({
    required BuildContext context,
    required ManagementItem item,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 32, color: item.color),
              ),
              const Spacer(),
              Text(
                item.title,
                style: GoogleFonts.quicksand(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}