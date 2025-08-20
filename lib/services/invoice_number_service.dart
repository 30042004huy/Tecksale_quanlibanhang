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

    // Lấy counter hiện tại từ Firebase
    final counterRef = _database.ref('nguoidung/${user.uid}/invoice_counters/$dateKey');
    final snapshot = await counterRef.get();

    int currentCounter = 1;
    if (snapshot.exists) {
      final counterData = InvoiceCounter.fromMap(snapshot.value as Map<dynamic, dynamic>);
      currentCounter = counterData.counter + 1;
    }

    // Cập nhật counter trong Firebase
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

    // Lấy counter hiện tại từ Firebase
    final counterRef = _database.ref('nguoidung/${user.uid}/invoice_counters/$dateKey');
    final snapshot = await counterRef.get();

    int currentCounter = 0;
    if (snapshot.exists) {
      final counterData = InvoiceCounter.fromMap(snapshot.value as Map<dynamic, dynamic>);
      currentCounter = counterData.counter;
    }

    // Tạo số hóa đơn hiện tại
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

    // Lấy counter hiện tại từ Firebase
    final counterRef = _database.ref('nguoidung/${user.uid}/invoice_counters/$dateKey');
    final snapshot = await counterRef.get();

    int currentCounter = 0;
    if (snapshot.exists) {
      final counterData = InvoiceCounter.fromMap(snapshot.value as Map<dynamic, dynamic>);
      currentCounter = counterData.counter;
    }

    // Tăng counter
    final newCounter = InvoiceCounter(dateKey: dateKey, counter: currentCounter + 1);
    await counterRef.set(newCounter.toMap());
  }
} 