// lib/services/invoice_number_service.dart
// (ĐÃ SỬA LỖI ĐỌC DỮ LIỆU BỊ LỖI/NULL)

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/invoice_counter_model.dart';

class InvoiceNumberService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Tạo số hóa đơn theo định dạng: 2 số cuối năm + tháng + 86 + ngày + số thứ tự (0001-9999)
  static Future<String> generateInvoiceNumber() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập');
    }

    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final dateKey = DateFormat('yyyyMMdd').format(now);

    final counterRef =
        _database.ref('nguoidung/${user.uid}/invoice_counters/$dateKey');
    final snapshot = await counterRef.get();

    int currentCounter = 1; // Mặc định là 1 nếu là ngày mới

    // --- ✨ SỬA LỖI TẠI ĐÂY ---
    // Đọc dữ liệu an toàn, bỏ qua fromMap để tránh lỗi 'Null' is not 'String'
    if (snapshot.exists && snapshot.value is Map) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      // Đọc 'counter' trực tiếp, nếu null hoặc lỗi thì dùng 0
      final lastCounter = (data['counter'] as num?)?.toInt() ?? 0;
      currentCounter = lastCounter + 1;
    }
    // --- KẾT THÚC SỬA LỖI ---

    // Cập nhật counter trong Firebase (Dùng model để GHI vẫn an toàn)
    final newCounter = InvoiceCounter(dateKey: dateKey, counter: currentCounter);
    await counterRef.set(newCounter.toMap());

    // Tạo số hóa đơn
    final sequenceNumber = currentCounter.toString().padLeft(4, '0');
    return '$yearSuffix$month${86}$day$sequenceNumber';
  }

  /// Lấy số hóa đơn hiện tại (không tăng counter)
  static Future<String> getCurrentInvoiceNumber() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập');
    }

    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final dateKey = DateFormat('yyyyMMdd').format(now);

    final counterRef =
        _database.ref('nguoidung/${user.uid}/invoice_counters/$dateKey');
    final snapshot = await counterRef.get();

    int currentCounter = 0; // Mặc định là 0 (đơn tiếp theo là 1)

    // --- ✨ SỬA LỖI TẠI ĐÂY ---
    if (snapshot.exists && snapshot.value is Map) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      // Đọc 'counter' trực tiếp, nếu null hoặc lỗi thì dùng 0
      currentCounter = (data['counter'] as num?)?.toInt() ?? 0;
    }
    // --- KẾT THÚC SỬA LỖI ---

    // Tạo số hóa đơn hiện tại (số tiếp theo)
    final sequenceNumber = (currentCounter + 1).toString().padLeft(4, '0');
    return '$yearSuffix$month${86}$day$sequenceNumber';
  }

  /// Tăng counter khi lưu đơn hàng
  static Future<void> incrementInvoiceCounter() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập');
    }

    final now = DateTime.now();
    final dateKey = DateFormat('yyyyMMdd').format(now);

    final counterRef =
        _database.ref('nguoidung/${user.uid}/invoice_counters/$dateKey');
    final snapshot = await counterRef.get();

    int currentCounter = 0;

    // --- ✨ SỬA LỖI TẠI ĐÂY ---
    if (snapshot.exists && snapshot.value is Map) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      // Đọc 'counter' trực tiếp, nếu null hoặc lỗi thì dùng 0
      currentCounter = (data['counter'] as num?)?.toInt() ?? 0;
    }
    // --- KẾT THÚC SỬA LỖI ---

    // Tăng counter
    final newCounter =
        InvoiceCounter(dateKey: dateKey, counter: currentCounter + 1);
    await counterRef.set(newCounter.toMap());
  }
}