import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'canhan.dart';
import 'thongtincuahang.dart';
import 'mauhoadon.dart';
import 'caidatmayin.dart';
import 'nhanvien.dart'; // New import
import 'cuahang.dart';   // New import
import 'dangnhap.dart';
import '../models/donhang_model.dart' as donhang;
import '../models/khachhang_model.dart' as khachhang;
import '../models/sanpham_model.dart' as sanpham;

import '../utils/format_currency.dart';
import '../services/invoice_number_service.dart';
import 'taohoadon.dart';

enum CustomerSelection { newCustomer, savedCustomer }

class ProductWithQuantity {
  final sanpham.SanPham product;
  int quantity;

  ProductWithQuantity({
    required this.product,
    required this.quantity,
  });
}

  void _moVeChungToi(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Về chúng tôi',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '"TeckSale ra đời với sứ mệnh đơn giản hóa quản lý bán hàng cho cá nhân và doanh nghiệp nhỏ, giúp bạn tập trung vào phát triển kinh doanh.\n\n'
                'Hiện ứng dụng đang trong giai đoạn phát triển, và chúng tôi rất cần những đóng góp quý báu của bạn tại mục chat để TeckSale ngày càng hoàn thiện.\n\n'
                'Chân thành cảm ơn sự đồng hành của bạn!"',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 100),
              Center(
                child: Text(
                  '© Thiết kế TeckSale bởi Huy Lữ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dangXuat(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DangNhapScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi đăng xuất: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSettingBox(
      BuildContext context, IconData icon, String title, Widget screen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Increased vertical padding for better spacing
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16), // Increased border radius for modern look
            border: Border.all(color: Colors.grey[200]!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), // Softer shadow
                blurRadius: 12, // Increased blur for depth
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16), // Slightly increased padding
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12), // Increased icon padding
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.08), // Softer opacity
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                ),
                child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
              ),
              const SizedBox(width: 16), // Increased spacing
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16, // Slightly larger font
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 18, // Slightly larger arrow
                color: Colors.grey[500],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVeChungToiBox(BuildContext context) {
    return _buildSettingBox(context, Icons.info_outline_rounded, 'Về chúng tôi', const SizedBox.shrink()); // Reuse method but no navigation
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Adjusted spacing
      child: GestureDetector(
        onTap: () async {
          final user = FirebaseAuth.instance.currentUser;
          final email = user?.email ?? 'tài khoản này';

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Modern radius
              child: Padding(
                padding: const EdgeInsets.all(24), // Increased padding
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red[600],
                      size: 56, // Larger icon
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Xác nhận đăng xuất',
                      style: TextStyle(
                        fontSize: 20, // Larger font
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bạn có chắc muốn đăng xuất khỏi tài khoản $email?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15, // Slightly larger
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _dangXuat(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4, // Increased elevation
                          ),
                          child: const Text(
                            'Đăng xuất',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: Container(
          height: 48, // Standardized height
          width: double.infinity, // Full width for better UX
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[600]!, Colors.red[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0, // Removed elevation for flat modern look
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.grey),
            onPressed: () => _moVeChungToi(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F0FE), Color(0xFFF5F7FA)],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildSettingBox(context, Icons.person_outline_rounded, 'Cá nhân', CaNhanScreen()),
                _buildSettingBox(context, Icons.store, 'Thông tin cửa hàng', ThongTinCuaHangScreen()),
                _buildSettingBox(context, Icons.receipt_long, 'Mẫu hóa đơn', MauHoaDonScreen()),
                _buildSettingBox(context, Icons.print, 'Cài đặt máy in', CaiDatMayInScreen()),
                _buildSettingBox(context, Icons.people_outline_rounded, 'Quản lý nhân viên', NhanVienScreen()), // New
                _buildSettingBox(context, Icons.restaurant_menu, 'Quản lý nhà hàng', CuaHangScreen()), // New
                _buildVeChungToiBox(context),
                const SizedBox(height: 20),
                _buildLogoutButton(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
