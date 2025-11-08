// lib/constants/admin_config.dart
import 'package:firebase_auth/firebase_auth.dart';

// ✨ 1. THAY ĐỔI TỪ STRING SANG LIST (DANH SÁCH)
// -------------------------------------------------------------------
// ✨ QUAN TRỌNG: 
// Dán TẤT CẢ các User UID của Admin vào danh sách này
// -------------------------------------------------------------------
const List<String> _adminUIDs = [
  'YOUR_ORIGINAL_ADMIN_UID', // <-- UID của bạn
  'gs8r9mj9GYPIFmw84uwOEkkGA6C3',   // <-- UID bạn mới cung cấp
  // Thêm các UID khác nếu cần
];

class AdminService {
  /// Kiểm tra xem người dùng hiện tại có phải là Admin không.
  static bool isCurrentUserAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    
    // ✨ 2. THAY ĐỔI LOGIC KIỂM TRA
    // Kiểm tra xem UID của người dùng có nằm trong danh sách admin không
    return _adminUIDs.contains(user.uid);
  }
}