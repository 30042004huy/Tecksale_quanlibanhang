import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'donhang.dart';
import '../models/donhang_model.dart' as donhang;
import '../models/khachhang_model.dart' as khachhang;
import '../models/sanpham_model.dart' as sanpham;
import 'barcode.dart'; // Giả sử cùng thư mục, nếu khác thì điều chỉnh path
import '../utils/format_currency.dart';
import '../services/invoice_number_service.dart';
import 'taohoadon.dart';
import 'package:google_fonts/google_fonts.dart';
import 'donhang.dart' as donhang_screen; // Thêm tiền tố 'as donhang_screen'
import 'nhanvien.dart' as nv_model; // Thêm tiền tố 'as nv_model'
import 'package:collection/collection.dart';
import 'thanhtoan.dart';
import '../services/custom_notification_service.dart';
import 'dart:math';


enum CustomerSelection { newCustomer, savedCustomer }

class ProductWithQuantity {
  final sanpham.SanPham product;
  int quantity;

  ProductWithQuantity({
    required this.product,
    required this.quantity,
  });
}

class TaoDonScreen extends StatefulWidget {
  final donhang.OrderData? orderToEdit;
  final List<ProductWithQuantity>? initialProducts;
  const TaoDonScreen({
    Key? key,
    this.orderToEdit,
    this.initialProducts, // ✨ THÊM VÀO CONSTRUCTOR
  }) : super(key: key);

  @override
  State<TaoDonScreen> createState() => _TaoDonScreenState();
}

class _TaoDonScreenState extends State<TaoDonScreen> {
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;
  late final String _userId;
  Future<bool> _checkInvoiceExists(String orderId) async {
  try {
    final savedSnapshot = await dbRef.child('nguoidung/$_userId/donhang/saved/$orderId').get();
    final completedSnapshot = await dbRef.child('nguoidung/$_userId/donhang/completed/$orderId').get();
    return savedSnapshot.exists || completedSnapshot.exists;
  } catch (e) {
    print('Lỗi kiểm tra số hóa đơn: $e');
    return false;
  }
}
  double _shippingCost = 0.0;
  double _otherCost = 0.0;
  double _discount = 0.0;
  bool _isCustomerSectionExpanded = true;
  bool _isNotesSectionExpanded = false; // Mặc định ghi chú nên đóng
  bool _isCostExpanded = true; 
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _otherCostController = TextEditingController(text: '0');
  String? _customerValidationError; // Biến giữ thông báo lỗi cho khách hàng (SĐT/Tên)
  // Biến trạng thái MỚI
  bool _shouldSaveNewCustomer = false; // Trạng thái của checkbox "Lưu khách hàng"
  khachhang.CustomerForInvoice? _foundCustomer; // Khách hàng tìm thấy qua SĐT
  Timer? _debounceTimer; // Dùng để trì hoãn việc tìm kiếm khi người dùng nhập SĐT
  List<TextEditingController> _productQuantityControllers = []; // <-- THÊM DÒNG NÀY
  List<FocusNode> _productFocusNodes = []; // <-- THÊM DÒNG NÀY
// Danh sách khách hàng giả định (Dùng để mô phỏng Database)
final List<khachhang.CustomerForInvoice> _mockCustomerList = [
  khachhang.CustomerForInvoice(name: 'Nguyễn Văn A', phone: '0901111222'),
  khachhang.CustomerForInvoice(name: 'Trần Thị B', phone: '0912345678'),
  // Thêm nhiều khách hàng mẫu khác nếu cần
];
// VỊ TRÍ: lib/screens/taodon.dart -> bên trong class _TaoDonScreenState

bool get _shouldShowSaveCustomerCheckbox {
  // 1. Lấy dữ liệu đã được làm sạch
  final name = _customerNameController.text.trim();
  final phone = _customerPhoneController.text.trim();

  // 2. Kiểm tra tên và SĐT có được nhập đủ không
  if (name.isEmpty || phone.length < 9) {
    return false; // Ẩn nếu chưa đủ thông tin
  }

  // 3. Kiểm tra xem SĐT đã tồn tại trong danh sách chưa
  final isDuplicate = _dsKhachHang.any((customer) => customer.phone == phone);
  if (isDuplicate) {
    return false; // Ẩn nếu SĐT đã có
  }

  // Nếu vượt qua tất cả các kiểm tra, trả về true
  return true;
}

void _loadInitialProducts() {
  // Nếu không có sản phẩm nào được truyền vào thì không làm gì
  if (widget.initialProducts == null || widget.initialProducts!.isEmpty) return;

  // Gán danh sách sản phẩm đã quét vào danh sách của màn hình
  _selectedProducts = List.from(widget.initialProducts!);

  // Hủy các controller cũ (nếu có) để tránh rò rỉ bộ nhớ
  for (var controller in _productQuantityControllers) {
    controller.dispose();
  }
  for (var node in _productFocusNodes) {
    node.dispose();
  }
  _productQuantityControllers = [];
  _productFocusNodes = [];

  // Tạo controller và focus node mới cho từng sản phẩm trong danh sách
  for (int i = 0; i < _selectedProducts.length; i++) {
    final item = _selectedProducts[i];
    _productQuantityControllers.add(
      TextEditingController(text: item.quantity.toString()),
    );

    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        _validateQuantityOnFocusLost(i);
      }
    });
    _productFocusNodes.add(focusNode);
  }

  // Cập nhật giao diện để hiển thị các sản phẩm
  setState(() {}); 
}

// HÀM TÌM KIẾM KHÁCH HÀNG
void _findCustomerByPhone(String phone) {
  final cleanedPhone = phone.replaceAll(RegExp(r'\D'), ''); 
  
  if (cleanedPhone.length < 9) {
    _foundCustomer = null;
    _selectedKhachHang = null;
    _shouldSaveNewCustomer = false; 
    setState(() {});
    return;
  }

  // 🔥 TÌM KIẾM TRONG DANH SÁCH ĐÃ TẢI TỪ FIREBASE (_dsKhachHang)
  final customer = _dsKhachHang.firstWhere(
    (c) => c.phone == cleanedPhone,
    // SỬ DỤNG LỚP CustomerForInvoice RỖNG NẾU KHÔNG TÌM THẤY
    orElse: () => khachhang.CustomerForInvoice(phone: '', name: ''), 
  );
  
  if (customer.name.isNotEmpty) {
    // Tìm thấy khách hàng
    _selectedKhachHang = customer; 
    _foundCustomer = customer;
    _customerNameController.text = customer.name; // Tự động điền Tên
    _shouldSaveNewCustomer = false; // Không cần lưu lại
  } else {
    // Không tìm thấy
    _selectedKhachHang = null;
    _foundCustomer = null;
    // Xóa tên nếu người dùng đã nhập SĐT mới, nếu không thì giữ lại tên
    if (_customerPhoneController.text.isNotEmpty) {
      _customerNameController.clear();
    }
    
  }
  
  setState(() {});
}

// HÀM LẮNG NGHE SỰ KIỆN NHẬP SỐ ĐIỆN THOẠI (DEBOUNCE)
void _onPhoneChanged(String phone) {
  if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
  
  // Trì hoãn 500ms trước khi tìm kiếm để người dùng nhập xong
  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
    _findCustomerByPhone(phone);
  });
}

// VỊ TRÍ: lib/screens/taodon.dart -> trong class _TaoDonScreenState

Future<bool> _saveNewCustomer({bool showSnackbar = true}) async {
  // 1. Lấy và kiểm tra dữ liệu đầu vào
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final name = _customerNameController.text.trim();
  final phone = _customerPhoneController.text.trim();

  if (phone.isEmpty || phone.length < 9) {
    _customerValidationError = 'Vui lòng nhập Số điện thoại hợp lệ (ít nhất 9 số).';
    if (mounted) setState(() {});
    return false;
  }
  if (name.isEmpty) {
    _customerValidationError = 'Vui lòng nhập Tên khách hàng.';
    if (mounted) setState(() {});
    return false;
  }
  if (uid == null) {
    _customerValidationError = 'Lỗi xác thực: Cần đăng nhập để lưu khách hàng.';
    if (mounted) setState(() {});
    return false;
  }
  
  // Nếu hợp lệ, xóa thông báo lỗi cũ
  _customerValidationError = null;
  if (mounted) setState(() {});

  // 2. Kiểm tra khách hàng đã tồn tại chưa
  final isDuplicate = _dsKhachHang.any((c) => c.phone == phone);

  if (!isDuplicate) {
    try {
      // 3. Tiến hành lưu lên Firebase
      final newCustomerRef = dbRef.child('nguoidung/$uid/khachhang').push();
      final newCustomer = khachhang.CustomerForInvoice(name: name, phone: phone);
      await newCustomerRef.set(newCustomer.toMap());

      if (mounted) {
        _dsKhachHang.add(newCustomer); // Cập nhật danh sách local
        
        // ✨ CẬP NHẬT GIAO DIỆN SAU KHI LƯU THÀNH CÔNG
        setState(() {
          _foundCustomer = newCustomer; // Đánh dấu đã tìm thấy -> checkbox sẽ tự ẩn
          _shouldSaveNewCustomer = false; // Bỏ tích checkbox về mặt logic
        });
        
        if (showSnackbar) {
          // ✨ SỬ DỤNG NOTIFICATION CHUNG CỦA ỨNG DỤNG
          CustomNotificationService.show(context, message: 'Đã lưu khách hàng mới thành công!');
        }
      }
      return true; // Trả về true báo hiệu lưu thành công
    } catch (e) {
      if (mounted) {
        _customerValidationError = 'Lỗi hệ thống khi lưu: ${e.toString()}';
        if (showSnackbar) {
          // ✨ SỬ DỤNG NOTIFICATION CHUNG CHO LỖI
          CustomNotificationService.show(context, message: 'Lỗi khi lưu khách hàng mới: $e', textColor: Colors.red);
        }
        setState(() {});
      }
      return false; // Trả về false báo hiệu lưu thất bại
    }
  }
  // Khách hàng đã tồn tại, không cần làm gì thêm
  return true;
}
  bool _isDiscountInPercent = false; 

// Hàm tính toán lại giá trị _discount (VND) nếu đang ở chế độ %
void _recalculateDiscountAmount() {
  // Chỉ tính lại khi đang ở chế độ %
  if (_isDiscountInPercent) {
    // 1. Lấy giá trị % người dùng đã nhập
    final discountPercent = double.tryParse(_discountController.text) ?? 0.0;
    
    // 2. Tính Tổng tiền hàng mới nhất (Không bao gồm phí vận chuyển/chi phí khác)
    final totalProductCost = _calculateTotalProductCost(); 
    
    // 3. Cập nhật giá trị _discount (VND)
    _discount = (totalProductCost * discountPercent) / 100.0;
  }
  // Nếu là VNĐ, giá trị _discount đã được cập nhật từ _handleDiscountValueChange nên không cần làm gì.
}

// SỬA ĐỔI HÀM NÀY: Giờ đây chỉ cần gọi lại _recalculateDiscountAmount()
void _handleDiscountValueChange(String value) {
  if (_isDiscountInPercent) {
    // Nếu là %, gọi hàm tính toán lại dựa trên TotalProductCost hiện tại
    _recalculateDiscountAmount(); 
  } else {
    // Nếu là VNĐ, lấy giá trị trực tiếp và cập nhật _discount
    _discount = double.tryParse(value) ?? 0;
  }
  setState(() {}); // Bắt buộc gọi setState để cập nhật UI ngay lập tức
}

// THAY THẾ HÀM TÍNH TỔNG THANH TOÁN
double _calculateGrandTotal() {
  // 🔥 GỌI HÀM NÀY ĐỂ ĐẢM BẢO _discount LUÔN ĐƯỢC CẬP NHẬT
  // theo Tổng tiền hàng mới nhất nếu đang ở chế độ %.
  _recalculateDiscountAmount();
  
  final totalProductCost = _calculateTotalProductCost();
  
  // Công thức: Tổng tiền hàng - Giảm giá (đã được cập nhật) + Phí vận chuyển + Chi phí khác
  return totalProductCost - _discount + _shippingCost + _otherCost;
  
}

  List<khachhang.CustomerForInvoice> _dsKhachHang = [];
  List<sanpham.SanPham> _dsSanPham = [];
  List<NhanVien> _dsNhanVien = [];
  NhanVien? _selectedNhanVien;
  
  StreamSubscription<DatabaseEvent>? _nhanVienSubscription;

  CustomerSelection _customerSelection = CustomerSelection.newCustomer;
  khachhang.CustomerForInvoice? _selectedKhachHang;
  List<ProductWithQuantity> _selectedProducts = [];
  bool _isLoading = true;
  bool _isSaving = false;

  StreamSubscription<DatabaseEvent>? _khachHangSubscription;
  StreamSubscription<DatabaseEvent>? _sanPhamSubscription;

  // HÀM MỚI: Tải trạng thái đóng/mở từ SharedPreferences
  Future<void> _loadSectionExpansionState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isCustomerSectionExpanded = prefs.getBool('isCustomerSectionExpanded') ?? true;
        _isNotesSectionExpanded = prefs.getBool('isNotesSectionExpanded') ?? false;
        _isCostExpanded = prefs.getBool('isCostExpanded') ?? true;
        
      });
    }
  }

  Future<void> _loadNhanVienData() async {
  final nhanVienRef = dbRef.child('nguoidung/$_userId/nhanvien');
  _nhanVienSubscription = nhanVienRef.onValue.listen((event) {
    if (mounted && event.snapshot.value != null) {
      final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _dsNhanVien = data.entries
            // Thêm "as Map" để Dart hiểu e.value là một Map
            .map((e) => NhanVien.fromMap(e.key, e.value as Map))
            .toList()
          ..sort((a, b) => a.ten.toLowerCase().compareTo(b.ten.toLowerCase()));
      });
    }
  });
}

Future<void> _loadSelectedEmployee() async {
  final prefs = await SharedPreferences.getInstance();
  final selectedEmployeeId = prefs.getString('selectedEmployeeId');
  if (selectedEmployeeId != null && mounted) {
    setState(() {
      _selectedNhanVien = _dsNhanVien.firstWhereOrNull(
        (nv) => nv.id == selectedEmployeeId,
      );
    });
  }
}


  @override
  void initState() {
    super.initState();
    if (user == null) {
      _userId = 'anonymous';
      setState(() => _isLoading = false);
    } else {
      _userId = user!.uid;
      _loadInitialData();
      _loadInvoiceNumber();
      _loadSectionExpansionState(); // ĐÃ THÊM: Gọi hàm tải trạng thái
    }
    _loadNhanVienData(); // Tải danh sách nhân viên
    _loadSelectedEmployee(); // Tải nhân viên mặc định từ SharedPreferences
     // SỬA LẠI ĐOẠN LOGIC NÀY
  if (widget.orderToEdit != null) {
    // Nếu là sửa đơn, ưu tiên tải dữ liệu đơn hàng cũ
    _loadOrderDataForEditing();
  } else if (widget.initialProducts != null) {
    // Nếu là tạo đơn từ màn hình quét, tải danh sách sản phẩm đã quét
    _loadInitialProducts();
  }
}

  @override
  void dispose() {
    _khachHangSubscription?.cancel();
    _sanPhamSubscription?.cancel();
    _invoiceNumberController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();

    _shippingCostController.dispose();

    _discountController.dispose();
    _notesController.dispose();
    _debounceTimer?.cancel();
    _nhanVienSubscription?.cancel();
      // ✨ THÊM VÒNG LẶP NÀY VÀO
  for (var controller in _productQuantityControllers) {
    controller.dispose();
  }
    for (var focusNode in _productFocusNodes) {
    focusNode.dispose();
  }
    super.dispose();
  }

  void _updateTotalCost() {
    if (mounted) {
      setState(() {});
    }
  }

// VỊ TRÍ: lib/screens/taodon.dart
// THAY THẾ TOÀN BỘ HÀM CŨ BẰNG HÀM NÀY

Future<void> _loadInvoiceNumber({int retries = 3}) async {
  try {
    // Vẫn thử tải như bình thường
    final invoiceNumber = await InvoiceNumberService.getCurrentInvoiceNumber();
    if (mounted) {
      setState(() {
        _invoiceNumberController.text = invoiceNumber;
      });
    }
  } catch (e) {
    // Nếu thất bại (do lỗi race condition hoặc mạng)
    print('Lỗi khi tải số hóa đơn (lần thử còn ${retries - 1}): $e');
    
    // ✨ PHẦN FIX LỖI: ✨
    // Chỉ thử lại nếu còn số lần thử (retries > 0)
    if (retries > 0 && mounted) {
      // Chờ 1 giây rồi gọi lại chính hàm này
      await Future.delayed(const Duration(seconds: 1));
      _loadInvoiceNumber(retries: retries - 1); // Thử lại
    } else if (mounted) {
      // Nếu đã hết số lần thử mà vẫn lỗi, hiển thị lỗi
      setState(() {
        _invoiceNumberController.text = 'Lỗi tải số HĐ';
      });
    }
  }
}

// VỊ TRÍ: lib/screens/taodon.dart
// THAY THẾ TOÀN BỘ HÀM NÀY

Future<void> _loadInitialData() async {
  final khachHangRef = dbRef.child('nguoidung/$_userId/khachhang');
  _khachHangSubscription = khachHangRef.onValue.listen((event) {
    if (mounted && event.snapshot.value != null) {
      final Map<dynamic, dynamic> data =
          event.snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _dsKhachHang = data.values
            .map((e) => khachhang.CustomerForInvoice.fromMap(e))
            .toList();
      });
    }
  });

  final sanPhamRef = dbRef.child('nguoidung/$_userId/sanpham');
  _sanPhamSubscription = sanPhamRef.onValue.listen((event) {
    if (mounted && event.snapshot.value != null && event.snapshot.value is Map) {
      final Map<dynamic, dynamic> data =
          event.snapshot.value as Map<dynamic, dynamic>;

      // --- BẮT ĐẦU GIẢI PHÁP ---
      final List<sanpham.SanPham> tempList = []; // Tạo 1 danh sách tạm

      // Dùng vòng lặp for an toàn
      for (var entry in data.entries) {
        try {
          // 1. Chỉ parse nếu value là Map
          if (entry.value is Map) {
            final sp = sanpham.SanPham.fromMap(entry.value, entry.key);
            tempList.add(sp);
          } else {
            // 2. Dữ liệu rác (không phải Map), bỏ qua
            print(
                'Cảnh báo (taodon): Bỏ qua sản phẩm lỗi/rác tại key: ${entry.key}');
          }
        } catch (e) {
          // 3. Lỗi parse (thiếu trường, sai kiểu), bỏ qua
          print('Lỗi parse sản phẩm (taodon) tại key ${entry.key}: $e');
        }
      }
      // --- KẾT THÚC GIẢI PHÁP ---

      if (mounted) {
        setState(() {
          _dsSanPham = tempList; // Gán danh sách đã được lọc sạch
        });
      }
    } else if (mounted) {
      // Trường hợp không có sản phẩm nào
      setState(() {
        _dsSanPham = [];
      });
    }
  }); // <<<--- 1. ĐÂY LÀ DẤU "});" BỊ THIẾU ĐỂ ĐÓNG HÀM LISTEN

  if (mounted) {
    setState(() => _isLoading = false);
  }

  if (widget.orderToEdit != null) {
    _loadOrderDataForEditing();
  }
} // <<<--- 2. ĐÂY LÀ DẤU "}" BỊ THIẾU ĐỂ ĐÓNG HÀM _loadInitialData

void _loadOrderDataForEditing() {
  if (widget.orderToEdit == null) return;

  final order = widget.orderToEdit!;
  
  _invoiceNumberController.text = order.orderId;
  _customerNameController.text = order.displayCustomerName;
  _customerPhoneController.text = order.displayCustomerPhone;
  _shippingCostController.text = order.shippingCost > 0 ? order.shippingCost.toString() : '';
  _discountController.text = order.discount > 0 ? order.discount.toString() : '';
  _notesController.text = order.notes;

   // ✨ HỦY VÀ XÓA CONTROLLER CŨ TRƯỚC KHI TẢI DỮ LIỆU MỚI
  for (var controller in _productQuantityControllers) {
    controller.dispose();
  }
    for (var focusNode in _productFocusNodes) { // <-- THÊM VÒNG LẶP NÀY
    focusNode.dispose();
  }
  _productQuantityControllers.clear();
  _productFocusNodes.clear(); // <-- THÊM DÒNG NÀY

  _selectedProducts = widget.orderToEdit!.items.asMap().entries.map((entry) {
    final index = entry.key;
    final item = entry.value;

    _productQuantityControllers.add(TextEditingController(text: item.quantity.toString()));
    
    // ✨ THÊM LOGIC TẠO VÀ LẮNG NGHE FOCUSNODE KHI SỬA ĐƠN
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        _validateQuantityOnFocusLost(index);
      }
    });
    _productFocusNodes.add(focusNode);

    final product = _dsSanPham.firstWhere(
      (p) => p.id == item.productId,
      orElse: () => sanpham.SanPham(id: item.productId, maSP: '', tenSP: item.name, donGia: item.unitPrice, donVi: item.unit),
    );
    return ProductWithQuantity(product: product, quantity: item.quantity);
  }).toList();

  _customerSelection = CustomerSelection.newCustomer;
  _selectedNhanVien = _dsNhanVien.firstWhereOrNull((nv) => nv.id == order.employeeId);

  if (mounted) setState(() {});
}

void _resetForm() {
  setState(() {
    _customerSelection = CustomerSelection.newCustomer;
    _selectedKhachHang = null;
    _foundCustomer = null; // Thêm dòng này để xóa thông tin khách hàng đã tìm thấy
    _customerNameController.clear();
    _customerPhoneController.clear();
    _shippingCostController.clear();
    _discountController.clear();
      _notesController.clear();

    // ✨ HỦY VÀ XÓA TẤT CẢ CONTROLLER CŨ
    for (var controller in _productQuantityControllers) {
      controller.dispose();
    }
    for (var focusNode in _productFocusNodes) { // <-- THÊM VÒNG LẶP NÀY
      focusNode.dispose();
    }
    _productQuantityControllers.clear();
    _productFocusNodes.clear(); // <-- THÊM DÒNG NÀY
    _selectedProducts.clear();

    // 🔥 DÒNG QUAN TRỌNG NHẤT ĐỂ SỬA LỖI
    _discount = 0;
    _shippingCost = 0;
    _otherCost = 0;
    _isDiscountInPercent = false; // Đưa về chế độ VNĐ mặc định

    // Không cần chọn lại nhân viên, giữ nguyên nhân viên đã chọn cho đơn tiếp theo
  });
  // Tải lại số hóa đơn mới
  _loadInvoiceNumber();
}

// DÁN HÀM HOÀN TOÀN MỚI NÀY VÀO TRONG class _TaoDonScreenState
void _validateQuantityOnFocusLost(int index) {
  final controller = _productQuantityControllers[index];
  int quantity = int.tryParse(controller.text) ?? 0;

  // Nếu số lượng trống hoặc nhỏ hơn 1, đặt lại là 1
  if (quantity <= 0) {
    setState(() {
      _selectedProducts[index].quantity = 1;
      controller.text = '1';
      _updateTotalCost();
    });
  }
}

// THAY THẾ HÀM _addProductToOrder CŨ BẰNG HÀM NÀY
void _addProductToOrder(sanpham.SanPham product, int quantity) {
  setState(() {
    final existingIndex = _selectedProducts.indexWhere((p) => p.product.id == product.id);
    if (existingIndex != -1) {
      _selectedProducts[existingIndex].quantity += quantity;
      _productQuantityControllers[existingIndex].text = _selectedProducts[existingIndex].quantity.toString();
    } else {
      _selectedProducts.add(ProductWithQuantity(product: product, quantity: quantity));
      _productQuantityControllers.add(TextEditingController(text: quantity.toString()));
      
      // ✨ THÊM LOGIC TẠO VÀ LẮNG NGHE FOCUSNODE MỚI
      final focusNode = FocusNode();
      final newIndex = _selectedProducts.length - 1;
      focusNode.addListener(() {
        // Khi người dùng không còn focus vào ô nhập liệu nữa
        if (!focusNode.hasFocus) {
          _validateQuantityOnFocusLost(newIndex);
        }
      });
      _productFocusNodes.add(focusNode);
    }
  });
  _updateTotalCost(); // Gọi cập nhật tổng tiền
}

// THAY THẾ HÀM _removeProductFromOrder CŨ BẰNG HÀM NÀY
void _removeProductFromOrder(int index) {
  setState(() {
    _productQuantityControllers[index].dispose();
    _productQuantityControllers.removeAt(index);
    _productFocusNodes[index].dispose(); // <-- THÊM DÒNG NÀY
    _productFocusNodes.removeAt(index); // <-- THÊM DÒNG NÀY
    _selectedProducts.removeAt(index);
  });
  _updateTotalCost();
}

  double _calculateTotalProductCost() {
    return _selectedProducts.fold(
        0.0, (sum, item) => sum + (item.product.donGia * item.quantity));
  }

  double _calculateTotalOrderCost() {
    final totalProductCost = _calculateTotalProductCost();
    final shippingCost = double.tryParse(_shippingCostController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    return totalProductCost + shippingCost - discount;
  }

  Future<bool> _updateInventory() async {
    try {
      for (var item in _selectedProducts) {
        final productRef = dbRef.child('nguoidung/$_userId/sanpham/${item.product.id}');
        final snapshot = await productRef.get();
        if (snapshot.exists) {
          final productData = Map<String, dynamic>.from(snapshot.value as Map);
          final currentStock = (productData['tonKho'] as int?) ?? 0;
          if (currentStock < item.quantity) {
            _showAlertDialog('Lỗi', 'Sản phẩm ${item.product.tenSP} không đủ tồn kho.');
            return false;
          }
          await productRef.update({
            'tonKho': currentStock - item.quantity,
          });
        }
      }
      return true;
    } catch (e) {
      _showAlertDialog('Lỗi', 'Không thể cập nhật tồn kho: $e');
      return false;
    }
  }

Future<void> _saveOrder(donhang.OrderStatus status) async {
  if (_selectedProducts.isEmpty) {
    CustomNotificationService.show(context, message: 'Vui lòng thêm ít nhất một sản phẩm.', textColor: Colors.orange);
    return;
  }

  if (status == donhang.OrderStatus.saved) {
    final canUpdateInventory = await _updateInventory();
    if (!canUpdateInventory) {
      return;
    }
  }

  setState(() => _isSaving = true);

  try {
    if (widget.orderToEdit != null) {
      final oldOrder = widget.orderToEdit!;
      final oldStatusPath = oldOrder.status.toString().split('.').last;
      await dbRef.child('nguoidung/$_userId/donhang/$oldStatusPath/${oldOrder.orderId}').remove();
    }

    // Kiểm tra số hóa đơn nếu lưu vào saved
    final orderData = _createOrderData(status);
    final orderId = orderData.orderId;
    if (status == donhang.OrderStatus.saved) {
      if (await _checkInvoiceExists(orderId)) {
        CustomNotificationService.show(context, message: 'Số hóa đơn đã tồn tại. Vui lòng thử lại.', textColor: Colors.red);
        return;
      }
    }
    if (status == donhang.OrderStatus.draft) {
      if (await _checkInvoiceExists(orderId)) {
        CustomNotificationService.show(context, message: 'Số hóa đơn đã tồn tại. Vui lòng thử lại.', textColor: Colors.red);
        return;
      }
    }


    if (widget.orderToEdit == null && (status == donhang.OrderStatus.saved || status == donhang.OrderStatus.draft)) {
      await InvoiceNumberService.incrementInvoiceCounter();
    }

    final orderRef = dbRef.child('nguoidung/$_userId/donhang/${status.toString().split('.').last}/$orderId');
    final orderMap = orderData.toMap();
    await orderRef.set(orderMap);

    if (widget.orderToEdit == null && (status == donhang.OrderStatus.saved || status == donhang.OrderStatus.draft)) {
      await _loadInvoiceNumber();
    }

    String message = '';
    if (widget.orderToEdit != null) {
      switch (status) {
        case donhang.OrderStatus.draft:
          message = 'Đã cập nhật đơn nháp thành công!';
          break;
        case donhang.OrderStatus.saved:
          message = 'Đã cập nhật đơn hàng thành công!';
          break;
        case donhang.OrderStatus.completed:
          message = 'Đã hoàn tất đơn hàng thành công!';
          break;
      }
    } else {
      switch (status) {
        case donhang.OrderStatus.draft:
          message = 'Đã lưu nháp!';
          break;
        case donhang.OrderStatus.saved:
          message = 'Đã lưu đơn hàng !';
          break;
        case donhang.OrderStatus.completed:
          message = 'Đã hoàn tất đơn hàng!';
          break;
      }
    }
     // --- THAY ĐỔI CHÍNH Ở ĐÂY ---
    // Hiển thị thông báo dựa trên trạng thái của đơn hàng
    if (status == donhang.OrderStatus.draft) {
      // 1. DÙNG THÔNG BÁO TÙY CHỈNH CHO LƯU NHÁP
      if (mounted) {
        CustomNotificationService.show(context, message: message);
      }
    } else if (status == donhang.OrderStatus.saved) {
      // 2. DÙNG DIALOG CHO LƯU ĐƠN (để có nút xem đơn hàng)
      _showAlertDialog('Thành công', message, showViewOrderButton: true);
    } else {
      // 3. DÙNG DIALOG CHO CÁC TRƯỜNG HỢP CÒN LẠI (ví dụ sửa đơn)
       _showAlertDialog('Thành công', message, showViewOrderButton: false);
    }
    // ----------------------------

    // Reset form và tải số hóa đơn mới nếu là tạo đơn mới
    if (widget.orderToEdit == null) {
        _resetForm();
        await _loadInvoiceNumber();
    }
  } catch (e) {
    CustomNotificationService.show(context, message: 'Lỗi: Không thể lưu đơn hàng.', textColor: Colors.red);
  } finally {
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }
}

donhang.OrderData _createOrderData(donhang.OrderStatus status) {
  String customerName;
  String customerPhone;
  if (_customerSelection == CustomerSelection.newCustomer) {
    customerName = _customerNameController.text.trim();
    customerPhone = _customerPhoneController.text.trim();
  } else {
    customerName = _selectedKhachHang?.name ?? '';
    customerPhone = _selectedKhachHang?.phone ?? '';
  }

  final List<donhang.OrderItem> orderItems = _selectedProducts.map((p) {
    return donhang.OrderItem(
      productId: p.product.id,
      name: p.product.tenSP,
      quantity: p.quantity,
      unit: p.product.donVi,
      unitPrice: p.product.donGia,
    );
  }).toList();

  return donhang.OrderData(
    orderId: _invoiceNumberController.text.trim(),
    orderDate: DateTime.now(),
    customerName: customerName,
    customerPhone: customerPhone,
    items: orderItems,
    shippingCost: double.tryParse(_shippingCostController.text) ?? 0.0,
    discount: double.tryParse(_discountController.text) ?? 0.0,
    notes: _notesController.text.trim(),
    status: status,
    employeeId: _selectedNhanVien?.id ?? '', // Lấy ID nhân viên, đây là cách làm đúng
  );
}

  void _showInvoicePreview() {
    if (_selectedProducts.isEmpty) {
      CustomNotificationService.show(context, message: 'Vui lòng thêm ít nhất một sản phẩm.', textColor: Colors.orange);
      return;
    }

    final orderData = _createOrderData(donhang.OrderStatus.draft);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaoHoaDonScreen(orderData: orderData),
      ),
    ).then((value) {
      if (value == true && mounted) {
        _resetForm();
      }
    });
  }

  void _createInvoice() {
    if (_selectedProducts.isEmpty) {
      CustomNotificationService.show(context, message: 'Vui lòng thêm ít nhất một sản phẩm.', textColor: Colors.orange);
      return;
    }

    final orderData = _createOrderData(donhang.OrderStatus.draft);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaoHoaDonScreen(orderData: orderData),
      ),
    ).then((value) {
      if (value == true && mounted) {
        _resetForm();
      }
    });
  }

void _showAlertDialog(String title, String message, {bool showViewOrderButton = false}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  title == 'Thành công' ? Icons.check_circle : Icons.error,
                  color: title == 'Thành công' ? Colors.green.shade600 : Colors.red.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              // THAY ĐỔI: Dùng if/else để quyết định hiển thị nút nào
              child: showViewOrderButton
                  ? Row( // Hiển thị cả 2 nút
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK', style: TextStyle(color: Colors.blue)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Đóng dialog
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const DonHangScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 0, 128, 255),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Xem đơn hàng'),
                        ),
                      ],
                    )
                  : ElevatedButton( // Chỉ hiển thị nút OK
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('OK'),
                      ),
            ),
          ],
        ),
      ),
    ),
  );
}



  Future<void> _showCustomerSelectionDialog() async {
    TextEditingController _searchController = TextEditingController();
    List<khachhang.CustomerForInvoice> filteredList = List.from(_dsKhachHang);

  // Thêm dòng code này để sắp xếp danh sách theo tên từ A-Z
  filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final result = await showDialog<khachhang.CustomerForInvoice>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterList(String keyword) {
              keyword = keyword.toLowerCase();
              setState(() {
                filteredList = _dsKhachHang.where((kh) {
                  return kh.name.toLowerCase().contains(keyword) ||
                      kh.phone.toLowerCase().contains(keyword);
                }).toList();
               // Thêm dòng code sắp xếp vào đây để danh sách sau khi lọc cũng được sắp xếp
              filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            });
          }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_search, color: Colors.blue, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Chọn khách hàng',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm khách hàng...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: _filterList,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredList.isEmpty
                          ? const Center(child: Text('Không tìm thấy khách hàng'))
                          : ListView.builder(
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final khachHang = filteredList[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pop(khachHang);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            spreadRadius: 1,
                                            blurRadius: 5,
                                            offset: const Offset(2, 3),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        title: Text(
                                          khachHang.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(khachHang.phone),
                                        trailing: const Icon(Icons.person_outline),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedKhachHang = result;
        _customerSelection = CustomerSelection.savedCustomer;
        _customerNameController.text = result.name;
        _customerPhoneController.text = result.phone;
      });
    }
  }

  Future<void> _showProductSelectionDialog() async {
    final TextEditingController searchController = TextEditingController();
    List<sanpham.SanPham> filteredProducts = List.from(_dsSanPham)
      ..sort((a, b) => a.maSP.compareTo(b.maSP));

    final result = await showDialog<sanpham.SanPham>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.shopping_cart, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Chọn sản phẩm',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                            tooltip: 'Quét mã barcode',
                            onPressed: () async {
                              Navigator.of(context).pop(); // Đóng dialog chọn sản phẩm
                              final updatedProducts = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BarcodeScannerScreen(initialProducts: _selectedProducts),
                                ),
                              );
                              if (updatedProducts != null && mounted) {
                                setState(() {
                                  _selectedProducts = List.from(updatedProducts); // Cập nhật list sản phẩm
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm sản phẩm...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.black, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value.isEmpty) {
                              filteredProducts = List.from(_dsSanPham)
                                ..sort((a, b) => a.maSP.compareTo(b.maSP));
                            } else {
                              filteredProducts = _dsSanPham
                                  .where((product) =>
                                      product.tenSP.toLowerCase().contains(value.toLowerCase()) ||
                                      product.maSP.toLowerCase().contains(value.toLowerCase()))
                                  .toList()
                                ..sort((a, b) => a.maSP.compareTo(b.maSP));
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: filteredProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  'Không tìm thấy sản phẩm',
                                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              )
                            :  ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final sanPham = filteredProducts[index];
return InkWell(
  // ✨ Bọc trong InkWell để toàn bộ thẻ có thể nhấn được
  onTap: () {
    // ✨ KIỂM TRA TỒN KHO TRƯỚC KHI THÊM
    if ((sanPham.tonKho ?? 0) <= 0) {
      // Nếu hết hàng, hiển thị thông báo và không làm gì cả
      CustomNotificationService.show(
        context,
        message: 'Sản phẩm "${sanPham.tenSP}" đã hết hàng.',
        textColor: Colors.red,
      );
      return; // Dừng lại
    }
    // Nếu còn hàng, thêm sản phẩm như bình thường
    Navigator.of(context).pop(sanPham);
  },
  borderRadius: BorderRadius.circular(10), // Đồng bộ bo góc với Card
  child: Card(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
    elevation: 2,
    // ✨ Thêm màu nền để phân biệt sản phẩm hết hàng
    color: (sanPham.tonKho ?? 0) > 0 ? const Color.fromARGB(255, 255, 255, 255) : Colors.grey.shade200,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: const Color.fromARGB(255, 144, 144, 144),
        width: 0.5,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sanPham.tenSP,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              // ✨ Chữ bị mờ đi nếu hết hàng
              color: (sanPham.tonKho ?? 0) > 0 ? Colors.black : Colors.grey.shade600,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã: ${sanPham.maSP ?? ''}'),
                    const SizedBox(height: 4),
                    Text(
                      'Giá: ${FormatCurrency.format(sanPham.donGia)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tồn kho: ${sanPham.tonKho ?? 0}',
                      style: TextStyle(
                        color: (sanPham.tonKho ?? 0) > 0 ? Colors.blueGrey : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ✨ THAY THẾ NÚT BẤM BẰNG ICON TRANG TRÍ
              Icon(
                Icons.add_shopping_cart,
                color: (sanPham.tonKho ?? 0) > 0 ? Colors.blue : Colors.grey.shade300,
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
                              },
                            ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      _addProductToOrder(result, 1);
    }
  }



Widget _buildEmployeeSection() {
  return Card(
    elevation: 00, // Độ nổi vừa phải
    margin: EdgeInsets.zero, // Loại bỏ margin mặc định của Card
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(2), // Viền cong nhẹ
      side: BorderSide(color: Colors.grey.shade300,), // Thêm viền mỏng
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0), 
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Nhân viên bán',
              style: GoogleFonts.roboto(fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: DropdownButton<NhanVien>(
              value: _selectedNhanVien,
              hint: Text(
                'Chọn nhân viên',
                style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey),
              ),
              isExpanded: true,
              items: _dsNhanVien.map((nv) {
                return DropdownMenuItem<NhanVien>(
                  value: nv,
                  child: Text(
                    nv.ten,
                    style: GoogleFonts.roboto(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (NhanVien? newValue) async {
                if (newValue != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('selectedEmployeeId', newValue.id);
                  setState(() {
                    _selectedNhanVien = newValue;
                  });
                }
              },
              underline: Container(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildInvoiceNumberSection() {
  return Card(
    elevation: 00, // Độ nổi vừa phải
    margin: EdgeInsets.zero, // Loại bỏ margin mặc định của Card
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(2), // Viền cong nhẹ
      side: BorderSide(color: Colors.grey.shade300,), // Thêm viền mỏng
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tiêu đề
          const Text(
            'Số hóa đơn:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8), 
          // Khu vực TextField để cho phép chỉnh sửa
          Expanded(
            child: TextField(
              controller: _invoiceNumberController,
              textAlign: TextAlign.left, // Để số nằm sát tiêu đề
              readOnly: false, // ĐÃ SỬA: Cho phép người dùng gõ/chỉnh sửa
              keyboardType: TextInputType.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700, // Màu đỏ
              ),
              decoration: const InputDecoration(
                hintText: 'Nhập số hóa đơn',
                isDense: true, // Thu nhỏ chiều cao
                contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0), // Loại bỏ padding bên trong
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// VỊ TRÍ: lib/screens/taodon.dart
// THAY THẾ TOÀN BỘ HÀM NÀY

Widget _buildCustomerSection() {
  // Lấy giá trị của SĐT và Tên hiện tại
  final phone = _customerPhoneController.text.trim();
  final name = _customerNameController.text.trim();

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 5), 
    elevation: 1, 
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5),
      side: const BorderSide(color: Colors.grey, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isCustomerSectionExpanded', !_isCustomerSectionExpanded);
            
            if (mounted) {
              setState(() {
                _isCustomerSectionExpanded = !_isCustomerSectionExpanded;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Thông tin khách hàng',
                  style: TextStyle(fontSize: 16),
                ),
                Icon(
                  _isCustomerSectionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ),
        
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isCustomerSectionExpanded ? null : 0,
          curve: Curves.easeInOut,
          child: SingleChildScrollView( 
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCustomerInputField(
                    label: 'Số điện thoại',
                    controller: _customerPhoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (value) {
                      // ✨ Gọi setState để giao diện cập nhật và kiểm tra lại điều kiện hiển thị checkbox
                      setState(() {
                        _onPhoneChanged(value); 
                        if (_customerValidationError != null) {
                            _customerValidationError = null; 
                        }
                      });
                    }, 
                    isPhone: true,
                  ),
                  const SizedBox(height: 12),

                  _buildCustomerInputField(
                    label: 'Tên khách hàng',
                    controller: _customerNameController,
                    readOnly: _foundCustomer != null, 
                    onChanged: (value) {
                      // ✨ Gọi setState để giao diện cập nhật và kiểm tra lại điều kiện hiển thị checkbox
                       setState(() {
                         if (_customerValidationError != null) {
                            _customerValidationError = null; 
                         }
                       });
                    }
                  ),
                  const SizedBox(height: 12),
                  
                  if (_customerValidationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _customerValidationError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),

                  // ✨ SỬ DỤNG GETTER MỚI ĐỂ QUYẾT ĐỊNH HIỂN THỊ CHECKBOX ✨
if (_shouldShowSaveCustomerCheckbox)
  Row(
    children: [
      Checkbox(
        value: _shouldSaveNewCustomer,
        onChanged: (bool? value) async {
          // Chỉ hành động khi người dùng TÍCH VÀO
          if (value == true) {
            // Cập nhật trạng thái ngay lập tức để người dùng thấy dấu tích
            setState(() {
              _shouldSaveNewCustomer = true;
            });

            // Gọi hàm lưu khách hàng
            final saved = await _saveNewCustomer();
            
            // Nếu lưu thất bại, tự động bỏ tích checkbox
            if (!saved && mounted) {
              setState(() {
                _shouldSaveNewCustomer = false;
              });
            }
            // Nếu lưu thành công, setState trong _saveNewCustomer sẽ làm ẩn checkbox này đi.
          } 
          // Nếu người dùng bỏ tích, chỉ cần cập nhật trạng thái
          else {
            setState(() {
              _shouldSaveNewCustomer = false;
            });
          }
        },
      ),
      const Text('Lưu khách hàng mới vào danh sách', style: TextStyle(fontSize: 14)),
    ],
  )
// ✨ KẾT THÚC ĐOẠN CODE THAY THẾ ✨


                  // ✨ HIỂN THỊ THÔNG TIN NẾU KHÁCH HÀNG ĐÃ TỒN TẠI ✨
                  else if (_foundCustomer != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, color: Colors.blue.shade600, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Khách hàng đã lưu: ${_foundCustomer!.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// HÀM HỖ TRỢ ĐỂ XÂY DỰNG Ô NHẬP LIỆU KHÁCH HÀNG (Thay thế hàm cũ)
Widget _buildCustomerInputField({
  required String label,
  required TextEditingController controller,
  TextInputType keyboardType = TextInputType.text,
  bool readOnly = false,
  Function(String)? onChanged,
  bool isPhone = false,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    readOnly: readOnly,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: readOnly ? Colors.grey.shade300 : Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: readOnly,
      fillColor: readOnly ? Colors.grey.shade100 : Colors.white,

      // ✨ THAY ĐỔI CHÍNH NẰM Ở ĐÂY ✨
      // Nếu là ô nhập SĐT (isPhone = true), hiển thị icon danh bạ
      // Nếu không, hiển thị null (không có icon)
      suffixIcon: isPhone 
        ? IconButton(
            icon: const Icon(Icons.contact_phone_outlined, color: Colors.blue),
            tooltip: 'Chọn khách hàng từ danh bạ',
            onPressed: () {
              // Gọi lại hàm popup chọn khách hàng đã có sẵn
              _showCustomerSelectionDialog(); 
            },
          )
        : null,
    ),
    style: TextStyle(
      color: readOnly ? Colors.grey.shade700 : Colors.black,
      fontWeight: readOnly ? FontWeight.bold : FontWeight.normal,
    ),
  );
}

Widget _buildProductSection() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 0.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Sản phẩm: Nút Quét + Nút Thêm (Nổi bật hơn)
        Card(
          elevation: 1, // Cho header nổi lên một chút
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sản phẩm',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nút Quét (Đã liên kết hàm)
                    InkWell(
                      onTap: () async {
  final updatedProducts = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BarcodeScannerScreen(initialProducts: _selectedProducts),
    ),
  );
  if (updatedProducts != null && mounted) {
    setState(() {
      _selectedProducts = List.from(updatedProducts); // Cập nhật list sản phẩm
    });
  }
},
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.qr_code_scanner, size: 25, color: const Color.fromARGB(255, 119, 119, 119)),
                            const SizedBox(width: 4),
                            Text('Quét', style: TextStyle(fontSize: 13, color: const Color.fromARGB(255, 127, 127, 127))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nút Thêm Sản phẩm
                    InkWell(
                      onTap: _showProductSelectionDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.add_box, size: 25, color: Colors.blue.shade600),
                            const SizedBox(width: 4),
                            Text('Thêm', style: TextStyle(fontSize: 13, color: Colors.blue.shade600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Danh sách sản phẩm (Thu gọn chiều cao)
        if (_selectedProducts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'Chưa có sản phẩm nào được chọn',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedProducts.length,
            itemBuilder: (context, index) {
              final item = _selectedProducts[index];
              final quantityController = _productQuantityControllers[index];
              


              return Card(
                elevation: 1, 
                margin: const EdgeInsets.only(bottom: 5), // Giảm margin
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0), // Giảm padding tối thiểu để thu hẹp chiều cao
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng 1: Tên sản phẩm và nút xóa
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.product.tenSP,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), // Font nhỏ hơn
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 18), // Icon nhỏ hơn
                            onPressed: () => _removeProductFromOrder(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6), // Giảm khoảng cách
                      
                      // Hàng 2: Giá (Trái) và Số lượng (Phải)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Giá sản phẩm (Kích thước chuẩn)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Giá:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              Text(
                                FormatCurrency.format(item.product.donGia),
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 45, 45, 45),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13, 
                                ),
                              ),
                            ],
                          ),
                          
                          // Vùng điều khiển Số lượng (Kích thước nhỏ)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Khung nhập SL có nút cộng trừ
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400, width: 1), 
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Nút Giảm (-)
                                    SizedBox(
                                      width: 25, // Rất nhỏ
                                      height: 25,
                                      child: IconButton(
                                        icon: const Icon(Icons.remove, size: 14), // Icon rất nhỏ
                                        color: Colors.blue.shade600,
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
  if (item.quantity > 1) {
    setState(() {
      item.quantity--;
      // Cập nhật trực tiếp vào controller
      quantityController.text = item.quantity.toString();
      _updateTotalCost();
    });
  }

                                        },
                                      ),
                                    ),
                                    
                                    // Ô nhập liệu Số lượng (SL)
                                    Container(
                                      // Thiết lập kích thước font/style ngang với giá tiền
                                      width: item.quantity.toString().length * 8.0 + 10, 
                                      constraints: const BoxConstraints(minWidth: 25, maxWidth: 50), 
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(color: Colors.grey.shade400),
                                          right: BorderSide(color: Colors.grey.shade400),
                                        ),
                                      ),
                                      child: IntrinsicWidth(
                                        child: TextField(
                                          controller: quantityController,
                                          focusNode: _productFocusNodes[index], // <-- GẮN FOCUSNODE
                                          onTap: () {
                                            // Tự động đưa con trỏ về cuối khi nhấn vào
                                            quantityController.selection = TextSelection.fromPosition(
                                              TextPosition(offset: quantityController.text.length),
                                            );
                                          },
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (value) {
                                            // ✨ CẬP NHẬT TỔNG TIỀN LIÊN TỤC
                                            final newQuantity = int.tryParse(value);
                                            if (newQuantity != null && newQuantity > 0) {
                                              item.quantity = newQuantity;
                                              _updateTotalCost(); // Gọi setState để cập nhật tổng tiền
                                            }
                                          },
                                          textInputAction: TextInputAction.done,
                                        ),
                                      ),
                                    ),

                                    // Nút Tăng (+)
                                    SizedBox(
                                      width: 25, // Rất nhỏ
                                      height: 25,
                                      child: IconButton(
                                        icon: const Icon(Icons.add, size: 14), // Icon rất nhỏ
                                        color: Colors.blue.shade600,
                                        padding: EdgeInsets.zero,
                                        // SỬA LẠI onPressed CỦA NÚT TĂNG (+)
onPressed: () {
  setState(() {
    item.quantity++;
    // Cập nhật trực tiếp vào controller
    quantityController.text = item.quantity.toString();
    _updateTotalCost();
  });
},
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4), 
                              // Đơn vị sản phẩm
                              Text(
                                item.product.donVi,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600), // Rất nhỏ
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}

Widget _buildNotesSection() {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 5), // Thêm margin để tách biệt
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5),
      side: const BorderSide(color: Colors.grey, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header với nút toggle
        InkWell(
          onTap: () async {
            // Lưu trạng thái mới vào SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isNotesSectionExpanded', !_isNotesSectionExpanded);

            if (mounted) {
              setState(() {
                _isNotesSectionExpanded = !_isNotesSectionExpanded;
              });
            }
          },
          // 🔥 ĐIỀU CHỈNH PADDING THEO TRẠNG THÁI:
          child: Padding(
            padding: _isNotesSectionExpanded 
                ? const EdgeInsets.all(16.0) // Padding lớn khi mở
                : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // 🔥 Padding nhỏ hơn (8.0) khi đóng
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ghi chú',
                  style: TextStyle(fontSize: 16),
                ),
                Icon(
                  _isNotesSectionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: const Color.fromARGB(255, 64, 133, 222),
                ),
              ],
            ),
          ),
        ),
        
        // 2. 🔥 NỘI DUNG (DÙNG ANIMATEDCONTAINER cho hiệu ứng mượt)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // Chiều cao bằng 0 khi thu gọn
          height: _isNotesSectionExpanded ? null : 0, 
          curve: Curves.easeInOut,
          child: SingleChildScrollView( 
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              // Giữ nguyên padding cho nội dung
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), 
              child: TextField(
                controller: _notesController,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onEditingComplete: () => FocusScope.of(context).unfocus(),
                decoration: const InputDecoration(
                  hintText: 'Nhập ghi chú...',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Color.fromARGB(255, 148, 148, 148)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color.fromARGB(255, 207, 207, 207)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildFixedActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // NÚT LƯU ĐƠN
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveOrder(donhang.OrderStatus.saved),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 88, 88, 88),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Text('Lưu đơn'),
            ),
          ),
          const SizedBox(width: 8),
          // NÚT HÓA ĐƠN
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _showInvoicePreview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Hóa đơn'),
            ),
          ),
          const SizedBox(width: 8),
          // NÚT THANH TOÁN MỚI
          Expanded(
            flex: 2, // Làm cho nút này to hơn
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () async { // <-- Thêm async ở đây
                if (_selectedProducts.isEmpty) {
                  CustomNotificationService.show(context, message: 'Thêm sản phẩm để thanh toán.', textColor: const Color.fromARGB(255, 232, 57, 8));
                  return;
                }

              // THÊM ĐOẠN KIỂM TRA SỐ HÓA ĐƠN
                final orderId = _invoiceNumberController.text.trim();
                if (await _checkInvoiceExists(orderId)) {
                  if (mounted) {
                    CustomNotificationService.show(
                      context,
                      message: 'Số hóa đơn "$orderId" đã tồn tại. Vui lòng nhập số khác.',
                      textColor: Colors.red,
                    );
                  }
                  return; // Dừng lại nếu trùng
                }
                // KẾT THÚC ĐOẠN KIỂM TRA

                final orderData = _createOrderData(donhang.OrderStatus.draft);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ThanhToanScreen(orderData: orderData)),
                );
              },
              icon: const Icon(Icons.payment),
              label: const Text('Thanh toán'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
}



@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Tạo đơn mới',
        style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)
      ),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(25),
        ),
      ),
      actions: [
        // ICON IN MỚI
        
            IconButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      // Hiển thị thông báo tùy chỉnh khi nhấn vào
                      CustomNotificationService.show(
                        context,
                        message: 'Chưa kết nối được tới máy in',
                        textColor: Colors.orange.shade800, // Sử dụng màu cam để cảnh báo
                      );
                    },
              icon: const Icon(Icons.print, color: Colors.white),
              tooltip: 'In hóa đơn',
            ),
        TextButton.icon(
          onPressed: _isSaving ? null : () => _saveOrder(donhang.OrderStatus.draft),
          icon: Icon(Icons.save, color: Colors.white, size: 20),
          label: Text(
            'Lưu nháp',
            style: GoogleFonts.roboto(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ],
    ),
body: GestureDetector(
  onTap: () {
    FocusScope.of(context).unfocus();
  },
  behavior: HitTestBehavior.opaque, // ✨ THÊM DÒNG NÀY
  child: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : Column(
            children: [
              // 1. PHẦN CÓ THỂ CUỘN (Chứa tất cả các mục trừ nút hành động)
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInvoiceNumberSection(),
                      const SizedBox(height: 20),
                      _buildEmployeeSection(), // Thêm mục Nhân viên bán
        const SizedBox(height: 10),
                      _buildProductSection(),
                      const SizedBox(height: 20),
                      
                      // 🔥 CHUYỂN ĐẾN ĐÂY: Mục Tổng tiền hàng/Thanh toán nằm ngay dưới sản phẩm và cuộn theo
                      _buildSummarySectionInScrollable(), 
                      const SizedBox(height: 20),
                      
                      // Mục Chi phí & Giảm giá (Có thể ẩn/hiện)
                      _buildCollapsibleCostSection(), 
                      const SizedBox(height: 20),

                      // Thông tin khách hàng (Sử dụng ExpansionTile)
                      _buildCustomerSection(), 
                      const SizedBox(height: 20),

                      // Ghi chú (Sử dụng ExpansionTile)
                      _buildNotesSection(), 
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // 2. NÚT HÀNH ĐỘNG CỐ ĐỊNH Ở DƯỚI CÙNG
              _buildFixedActionButtons(),
            ],
          ),
          ),
  );
}
// Đây là mục Tổng tiền hàng và Tổng thanh toán đã được tách riêng và cố định
// THAY THẾ HÀM _buildSummarySectionFixed CŨ BẰNG HÀM NÀY
Widget _buildSummarySectionInScrollable() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10), // Giữ padding nội bộ
    // LOẠI BỎ BoxShadow VÌ NÓ KHÔNG CÒN LÀ MỤC CỐ ĐỊNH
    decoration: BoxDecoration( 
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade300, width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Tổng tiền hàng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng tiền hàng:',
                style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 16), // Thêm khoảng cách nhỏ
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    FormatCurrency.format(_calculateTotalProductCost()),
                    style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 15, color: Colors.grey),
          // Tổng thanh toán
          // ĐOẠN CODE MỚI CHO "TỔNG THANH TOÁN"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng thanh toán:',
                style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(width: 16), // Thêm khoảng cách nhỏ
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    FormatCurrency.format(_calculateGrandTotal()),
                    style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                    
                  ),
                ),
              ),
            ],
          ),
// --- CẢNH BÁO KHI VƯỢT GIỚI HẠN ---
          if (_calculateGrandTotal() > 999999999999)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Số tiền vượt giới hạn',
                    style: GoogleFonts.roboto(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

// 2. PHẦN CHI PHÍ CÓ THỂ ẨN/HIỆN
Widget _buildCollapsibleCostSection() {
  // Logic ẩn/hiện Chi phí bằng AnimatedContainer để có hiệu ứng nhỏ gọn
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 5), 
    elevation: 1, 
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5),
      side: const BorderSide(color: Colors.grey, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (Nút ẩn/hiện)
        InkWell(
           onTap: () async {
            // 1. TẠO GIÁ TRỊ MỚI (Tức là ngược lại với trạng thái hiện tại)
            final newValue = !_isCostExpanded;
            
            // 2. 🔥 LƯU VÀO SHAPEPREFERENCES SỬ DỤNG KEY CHÍNH XÁC
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isCostExpanded', newValue);  // Sửa key: thống nhất thành 'isCostExpanded'

            // 3. CẬP NHẬT TRẠNG THÁI CỤC BỘ
            if (mounted) {
              setState(() {
                _isCostExpanded = newValue;
              });
            }
          },
          
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chi phí & Giảm giá',
                  style: GoogleFonts.roboto(fontSize: 16),
                ),
                Icon(
                  _isCostExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ),

        // Nội dung Chi phí (Ẩn/Hiện bằng cách điều chỉnh chiều cao)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isCostExpanded ? null : 0, // Ẩn khi height = 0
          curve: Curves.easeInOut,
          child: SingleChildScrollView( 
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCostInputField('Phí vận chuyển', _shippingCostController, (value) {
                    _shippingCost = double.tryParse(value) ?? 0;
                    setState(() {});
                  }),
                  
                  // 🔥 SỬ DỤNG HÀM XỬ LÝ MỚI CHO GIẢM GIÁ
                  _buildCostInputField('Giảm giá', _discountController, _handleDiscountValueChange, isDiscount: true), 
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// 3. HÀM HỖ TRỢ CHO Ô NHẬP LIỆU CHI PHÍ
Widget _buildCostInputField(String label, TextEditingController controller, Function(String) onChanged, {bool isDiscount = false}) {
  
  // Chuỗi suffix hiển thị trong ô nhập liệu
  String suffixText = isDiscount ? (_isDiscountInPercent ? '%' : 'VNĐ') : 'VNĐ';
  
  // Màu sắc cho suffix (giảm giá là Đỏ, chi phí là Xanh lá)
  Color suffixColor = isDiscount ? Colors.red : Colors.green;
  
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.roboto(fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              
              // STYLING CHUNG
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              
              // 🔥 Hiển thị Suffix (VNĐ / %)
              suffixText: suffixText,
              suffixStyle: GoogleFonts.roboto(
                color: suffixColor, 
                fontWeight: FontWeight.bold // Làm cho ký hiệu nổi bật
              ),
              
              // 🔥 Nút chuyển đổi (CHỈ DÙNG CHO GIẢM GIÁ)
              suffixIcon: isDiscount ? _buildDiscountTypeToggle(controller) : null,
              
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

// HÀM HỖ TRỢ MỚI (chuyển đổi kiểu) - Đảm bảo hàm này nằm sau _buildCostInputField
Widget _buildDiscountTypeToggle(TextEditingController controller) {
  return InkWell(
    onTap: () {
      setState(() {
        _isDiscountInPercent = !_isDiscountInPercent;
        // Đặt lại input và giá trị giảm giá khi chuyển đổi
        controller.text = '0'; 
        _handleDiscountValueChange('0');
      });
    },
    // 🔥 Thay thế bằng biểu tượng chuyển đổi đơn giản và màu sắc
    child: Padding(
      padding: const EdgeInsets.only(right: 8.0, left: 4.0),
      child: Icon(
        _isDiscountInPercent ? Icons.attach_money : Icons.percent,
        color: _isDiscountInPercent ? Colors.green.shade700 : Colors.blue.shade700,
        size: 20,
      ),
    ),
  );
}
}