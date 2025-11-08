// lib/constants/features_config.dart
import 'package:flutter/material.dart';

// 1. Định nghĩa Model cho một Chức Năng
//    Chúng ta chỉ lưu dữ liệu tĩnh (ID, tên, icon).
//    Phần logic (hàm onTap) sẽ nằm ở TrangChuScreen.
class FeatureConfig {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const FeatureConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

// 2. Định nghĩa TOÀN BỘ các chức năng mà ứng dụng có
//    Đây là "NGUỒN DỮ LIỆU GỐC".
const List<FeatureConfig> kAllFeatureItems = [
  FeatureConfig(
    id: 'taodon',
    icon: Icons.note_add,
    label: "Tạo đơn",
    color: Color.fromARGB(255, 209, 162, 20),
  ),
  FeatureConfig(
    id: 'quetdon',
    icon: Icons.barcode_reader,
    label: "Quét đơn",
    color: Color.fromARGB(255, 22, 162, 129),
  ),
  FeatureConfig(
    id: 'donhang',
    icon: Icons.inventory_2,
    label: "Đơn hàng",
    color: Color.fromARGB(255, 200, 104, 8),
  ),
  FeatureConfig(
    id: 'sanpham',
    icon: Icons.all_inbox,
    label: "Sản phẩm",
    color: Color.fromARGB(255, 6, 119, 189),
  ),
  FeatureConfig(
    id: 'khachhang',
    icon: Icons.people,
    label: "Khách hàng",
    color: Color.fromARGB(255, 64, 127, 15),
  ),
  FeatureConfig(
    id: 'quanlyban',
    icon: Icons.restaurant_menu,
    label: "Quản Lý Bàn",
    color: Color.fromARGB(255, 204, 170, 0),
  ),
  FeatureConfig(
    id: 'congno',
    icon: Icons.request_quote_outlined,
    label: "Công nợ",
    color: Color.fromARGB(255, 194, 56, 47),
  ),
  FeatureConfig(
    id: 'baocao',
    icon: Icons.leaderboard,
    label: "Báo cáo",
    color: Color.fromARGB(255, 76, 97, 221),
  ),
  FeatureConfig(
    id: 'taqr',
    icon: Icons.qr_code,
    label: "Tạo QR",
    color: Color.fromARGB(255, 125, 45, 45),
  ),
  FeatureConfig(
    id: 'nhapkho',
    icon: Icons.add_to_photos,
    label: "Nhập kho",
    color: Color.fromARGB(255, 0, 128, 255),
  ),
  const FeatureConfig(
  id: 'quanly_website',
  label: 'Quản lý Website',
  icon: Icons.public,
  color: Colors.teal, // Bạn có thể chọn màu khác
),
  // ✨ Nếu sau này bạn có thêm chức năng, hãy thêm vào đây
];