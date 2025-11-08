// lib/services/data_cache_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// Import các model của bạn
// (Đảm bảo các đường dẫn này đúng với cấu trúc dự án của bạn)
import '../models/sanpham_model.dart';
import '../models/khachhang_model.dart'; 
import 'package:tecksale_quanlybanhang/screens/donhang.dart' show NhanVien; // Lấy class NhanVien từ donhang.dart


class DataCacheService {
  // 1. Tạo Singleton
  static final DataCacheService _instance = DataCacheService._internal();
  factory DataCacheService() => _instance;
  DataCacheService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  // 2. Các biến Listener
  StreamSubscription<DatabaseEvent>? _productListener;
  StreamSubscription<DatabaseEvent>? _customerListener;
  StreamSubscription<DatabaseEvent>? _employeeListener;

  // 3. CÁC KHO CACHE
  List<SanPham> _products = [];
  List<CustomerForInvoice> _customers = [];
  List<NhanVien> _employees = [];

  bool _isLoading = false;
  bool _isLoaded = false;
  String? _currentUid;

  // 4. Các Getters để các trang khác truy cập
  List<SanPham> get products => _products;
  List<CustomerForInvoice> get customers => _customers;
  List<NhanVien> get employees => _employees;
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;

  // 5. HÀM TẢI NGẦM TẤT CẢ
  Future<void> startListeners() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Nếu đã chạy cho user này rồi thì thôi
    if (_isLoaded && _currentUid == user.uid) return;

    _isLoading = true;
    _currentUid = user.uid;

    // Hủy các listener cũ (nếu đổi tài khoản)
    await dispose();

    // -- Tải Sản Phẩm --
    _productListener = _dbRef.child('nguoidung/${user.uid}/sanpham').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _products = data.entries.map((e) => SanPham.fromMap(e.value, e.key)).toList()
          ..sort((a, b) => a.tenSP.compareTo(b.tenSP));
      } else {
        _products = [];
      }
      _checkIfAllLoaded();
    }, onError: (e) => print("DataCache Lỗi (Sản phẩm): $e"));

    // -- Tải Khách Hàng --
    _customerListener = _dbRef.child('nguoidung/${user.uid}/khachhang').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _customers = data.values.map((e) => CustomerForInvoice.fromMap(e)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
      } else {
        _customers = [];
      }
      _checkIfAllLoaded();
    }, onError: (e) => print("DataCache Lỗi (Khách hàng): $e"));

    // -- Tải Nhân Viên --
    _employeeListener = _dbRef.child('nguoidung/${user.uid}/nhanvien').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _employees = data.entries.map((e) => NhanVien.fromMap(e.key, e.value as Map)).toList()
          ..sort((a, b) => a.ten.compareTo(b.ten));
      } else {
        _employees = [];
      }
      _checkIfAllLoaded();
    }, onError: (e) => print("DataCache Lỗi (Nhân viên): $e"));
  }

  // 6. Hàm kiểm tra
  void _checkIfAllLoaded() {
    // Chỉ cần 3 listener được gán là coi như bắt đầu tải
    if (_productListener != null && _customerListener != null && _employeeListener != null) {
      _isLoading = false;
      _isLoaded = true;
    }
  }

  // 7. Hàm tải gấp (nếu cần)
  Future<void> loadAllDataNow() async {
    if (_isLoaded) return; // Đã tải rồi

    await startListeners(); // Khởi động

    // Đợi tối đa 5 giây
    int waitTime = 0;
    while (!_isLoaded && waitTime < 5000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitTime += 100;
    }
  }

  // 8. Hủy
  Future<void> dispose() async {
    await _productListener?.cancel();
    await _customerListener?.cancel();
    await _employeeListener?.cancel();
    _productListener = null;
    _customerListener = null;
    _employeeListener = null;
    _isLoaded = false;
    _currentUid = null;
  }
}