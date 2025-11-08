// lib/constants/feature_handlers.dart
import 'package:flutter/material.dart';
import '../screens/taodon.dart';
import '../screens/barcode.dart'; // File này phải export ProductWithQuantity
import '../screens/donhang.dart';
import '../screens/sanpham.dart';
import '../screens/khachhang.dart';
import '../screens/cuahang.dart';
import '../screens/congno.dart';
import '../screens/baocao.dart';
import '../screens/taoqr.dart';
import '../screens/nhapkho.dart';
import '../screens/website_management_screen.dart'; // ✨ THÊM DÒNG NÀY
import '../constants/admin_config.dart';
import '../services/custom_notification_service.dart';

// Định nghĩa map các hàm xử lý
final Map<String, Function(BuildContext)> kFeatureTapHandlers = {
  'taodon': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TaoDonScreen()));
  },
  'quetdon': (BuildContext context) async {
    final scannedProducts = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(initialProducts: []),
      ),
    );
    // Giả định ProductWithQuantity được export từ barcode.dart
    if (scannedProducts != null && scannedProducts is List<ProductWithQuantity>) { 
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaoDonScreen(initialProducts: scannedProducts),
        ),
      );
    }
  },
  'donhang': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DonHangScreen()));
  },
  'sanpham': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SanPhamScreen()));
  },
  'khachhang': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => KhachHangScreen()));
  },
  'quanlyban': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CuaHangScreen()));
  },
  'congno': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CongNoScreen()));
  },
  'baocao': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BaoCaoScreen()));
  },
  'taqr': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaoQRScreen()));
  },
  'nhapkho': (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NhapKhoScreen()));
  },
  'quanly_website': (BuildContext context) {
    // Kiểm tra quyền admin
    if (AdminService.isCurrentUserAdmin()) {
      // Nếu là Admin: Mở màn hình
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WebsiteManagementScreen()));
    } else {
      // Nếu không phải Admin: Hiển thị thông báo tùy chỉnh
      CustomNotificationService.show(
        context,
        message: 'Bạn không có quyền truy cập chức năng này.',
        backgroundColor: Colors.red[50]!, // Màu nền đỏ nhạt
        textColor: Colors.red[700]!, // Chữ đỏ đậm
      );
    }
  },
};