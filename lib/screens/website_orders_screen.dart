// lib/screens/website_orders_screen.dart
// ✨ ĐÃ THÊM LOGIC TRỪ TỒN KHO KHI XÁC NHẬN ĐƠN ✨

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../models/donhang_model.dart' hide FormatCurrency;
import '../utils/format_currency.dart';

import '../services/persistent_notification_service.dart';
import '../services/custom_notification_service.dart';

// Class NhanVien (Sao chép từ donhang.dart để dùng tạm)
class NhanVien {
  final String id;
  final String ten;
  final String ma;
  final int timestamp;

  const NhanVien({
    required this.id,
    required this.ten,
    required this.ma,
    required this.timestamp,
  });

  factory NhanVien.fromMap(String id, Map map) => NhanVien(
        id: id,
        ten: map['ten']?.trim() ?? 'Chưa đặt tên',
        ma: map['ma']?.trim() ?? '',
        timestamp: map['timestamp'] is int
            ? map['timestamp']
            : DateTime.now().millisecondsSinceEpoch,
      );
}

class WebsiteOrdersScreen extends StatefulWidget {
  final int? initialTab;

  const WebsiteOrdersScreen({super.key, this.initialTab});

  @override
  State<WebsiteOrdersScreen> createState() => _WebsiteOrdersScreenState();
}

class _WebsiteOrdersScreenState extends State<WebsiteOrdersScreen>
    with SingleTickerProviderStateMixin {
  final dbRef = FirebaseDatabase.instance.ref();
  User? user = FirebaseAuth.instance.currentUser;

  late TabController _tabController;
  Map<String, dynamic> _webOrders = {}; // Tab 1
  List<OrderData> _savedOrders = []; // Tab 2
  List<OrderData> _completedOrders = []; // Tab 3
  List<NhanVien> _allEmployees = [];

  bool _isLoadingWebOrders = true;
  bool _isLoadingSavedOrders = true;
  bool _isLoadingCompletedOrders = true;
  bool _isConfirming = false;

  StreamSubscription? _webOrdersSub;
  StreamSubscription? _savedOrdersSub;
  StreamSubscription? _completedOrdersSub;
  StreamSubscription? _employeeSub;

  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  int _currentTabIndex = 0;
  Set<String> _selectedOrderIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );
    _currentTabIndex = widget.initialTab ?? 0;
    _tabController.addListener(_handleTabSelection);

    if (user != null) {
      _listenToWebOrders();
      _listenToSavedOrders();
      _listenToCompletedOrders();
      _loadEmployees();
    } else {
      setState(() {
        _isLoadingWebOrders = false;
        _isLoadingSavedOrders = false;
        _isLoadingCompletedOrders = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _webOrdersSub?.cancel();
    _savedOrdersSub?.cancel();
    _completedOrdersSub?.cancel();
    _employeeSub?.cancel();
    _shippingCostController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
        _isSelectionMode = false;
        _selectedOrderIds.clear();
      });
    }
  }

  void _toggleSelectionMode([String? initialOrderId]) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedOrderIds.clear();
      if (_isSelectionMode && initialOrderId != null) {
        _selectedOrderIds.add(initialOrderId);
      }
    });
  }

  void _toggleOrderItemSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
      if (_selectedOrderIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  List<Widget> _buildAppBarActions() {
    if (_isSelectionMode) {
      return [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Xóa các mục đã chọn',
          onPressed: _selectedOrderIds.isEmpty ? null : _deleteSelectedOrders,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Hủy chọn',
          onPressed: () => _toggleSelectionMode(),
        ),
      ];
    } else if (_currentTabIndex == 0) {
      return [
        IconButton(
          icon: const Icon(Icons.checklist_rtl_outlined),
          tooltip: 'Chọn nhiều mục',
          onPressed: () => _toggleSelectionMode(),
        ),
      ];
    }
    return [];
  }

  // (Các hàm lắng nghe _listenTo... không đổi)
  void _listenToWebOrders() {
    _webOrdersSub = dbRef
        .child('website_data/${user!.uid}/orders/')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> rawData =
            event.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> correctlyTypedMap = {};
        rawData.forEach((key, value) {
          if (key is String && value is Map) {
            if (value['status'] == 'MoiDat') {
              correctlyTypedMap[key] = Map<String, dynamic>.from(value);
            }
          }
        });
        setState(() => _webOrders = correctlyTypedMap);
      } else {
        setState(() => _webOrders = {});
      }
      setState(() => _isLoadingWebOrders = false);
    });
  }

  void _listenToSavedOrders() {
    _savedOrdersSub = dbRef
        .child('nguoidung/${user!.uid}/donhang/saved')
        .onValue
        .listen((event) {
      final List<OrderData> tempList = [];
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.entries) {
          try {
            tempList
                .add(OrderData.fromMap(Map<String, dynamic>.from(entry.value)));
          } catch (e) {
            print('Lỗi parse (saved) đơn hàng ${entry.key}: $e');
          }
        }
      }
      tempList.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      setState(() {
        _savedOrders = tempList;
        _isLoadingSavedOrders = false;
      });
    });
  }

  void _listenToCompletedOrders() {
    _completedOrdersSub = dbRef
        .child('nguoidung/${user!.uid}/donhang/completed')
        .onValue
        .listen((event) {
      final List<OrderData> tempList = [];
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        for (var entry in data.entries) {
          try {
            tempList
                .add(OrderData.fromMap(Map<String, dynamic>.from(entry.value)));
          } catch (e) {
            print('Lỗi parse (completed) đơn hàng ${entry.key}: $e');
          }
        }
      }
      tempList.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      setState(() {
        _completedOrders = tempList;
        _isLoadingCompletedOrders = false;
      });
    });
  }

  void _loadEmployees() {
    _employeeSub = dbRef
        .child('nguoidung/${user!.uid}/nhanvien')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final employees = data.entries
            .map((e) => NhanVien.fromMap(e.key, e.value as Map))
            .toList();
        setState(() => _allEmployees = employees);
      }
    });
  }

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  // ✨ HÀM MỚI: TRỪ TỒN KHO ✨
  // Logic tương tự như _updateInventory trong taodon.dart
  Future<bool> _deductInventoryFromWebOrder(List<OrderItem> items) async {
    if (user == null) {
      return false;
    }
    final String uid = user!.uid;

    try {
      for (var item in items) {
        if (item.productId.isEmpty) {
          print(
              'Warning: Product ${item.name} has no ID, skipping inventory update.');
          continue;
        }

        final productRef =
            dbRef.child('nguoidung/$uid/sanpham/${item.productId}');
        final snapshot = await productRef.get();

        if (snapshot.exists) {
          final productData = Map<String, dynamic>.from(snapshot.value as Map);
          final currentStock = (productData['tonKho'] as int?) ?? 0;

          if (currentStock < item.quantity) {
            // Lỗi không đủ hàng
            if (mounted) {
              CustomNotificationService.show(
                context,
                message:
                    'Lỗi: Sản phẩm "${item.name}" không đủ tồn kho (Còn $currentStock, cần ${item.quantity}).',
                textColor: Colors.red,
                duration: const Duration(milliseconds: 3000),
              );
            }
            return false; // Dừng quá trình
          }

          // Trừ tồn kho
          await productRef.update({
            'tonKho': currentStock - item.quantity,
          });
        } else {
          // Lỗi không tìm thấy SP
          if (mounted) {
            CustomNotificationService.show(
              context,
              message:
                  'Lỗi: Không tìm thấy sản phẩm "${item.name}" (ID: ${item.productId}) trong kho.',
              textColor: Colors.red,
              duration: const Duration(milliseconds: 3000),
            );
          }
          return false; // Dừng quá trình
        }
      }
      // Nếu vòng lặp hoàn tất, tất cả sản phẩm đã được trừ kho
      return true;
    } catch (e) {
      if (mounted) {
        CustomNotificationService.show(
          context,
          message: 'Lỗi nghiêm trọng khi cập nhật tồn kho: $e',
          textColor: Colors.red,
          duration: const Duration(milliseconds: 3000),
        );
      }
      return false;
    }
  }

// --- HÀM XÁC NHẬN ĐƠN HÀNG (✨ ĐÃ SỬA LỖI TREO UI) ---
// --- HÀM XÁC NHẬN ĐƠN HÀNG (✨ ĐÃ SỬA LỖI TREO UI) ---
  Future<void> _confirmOrder(
    BuildContext dialogContext,
    String webOrderId,
    Map<String, dynamic> originalOrderData,
    Map<String, String> editedCustomerInfo,
    String editedNotes,
    double shippingCost,
    double discount,
  ) async {
    if (user == null || _isConfirming) return;

    setState(() => _isConfirming = true);

    try {
      final List<dynamic> rawItems = originalOrderData['items'] as List<dynamic>;
      final double totalFromWeb =
          (originalOrderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final String newOrderId = webOrderId;

      final Map<String, dynamic> newCustomerInfo = {
        'name': editedCustomerInfo['name']?.trim(),
        'phone': editedCustomerInfo['phone']?.trim(),
        'email': editedCustomerInfo['email']?.trim(),
        'address': editedCustomerInfo['address']?.trim(),
        'notes': editedCustomerInfo['notes']?.trim(),
      };

      String finalNotes = editedNotes.trim();
      String newAddress = editedCustomerInfo['address']?.trim() ?? '';

      if (newAddress.isNotEmpty) {
        if (finalNotes.isNotEmpty) {
          finalNotes += "\n${newAddress}";
        } else {
          finalNotes = newAddress;
        }
      }

      List<OrderItem> secureItems = [];
      for (var item in rawItems) {
        final map = Map<String, dynamic>.from(item);
        secureItems.add(OrderItem(
            productId: map['id'] ?? '',
            name: map['tenSP'] ?? 'Lỗi tên SP',
            unit: map['donVi'] ?? 'cái',
            quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            unitPrice: (map['giaBan'] as num?)?.toDouble() ?? 0.0));
      }

      // ✨ BƯỚC MỚI: KIỂM TRA VÀ TRỪ TỒN KHO ✨
      final bool inventoryDeducted =
          await _deductInventoryFromWebOrder(secureItems);

      if (!inventoryDeducted) {
        // Thông báo lỗi đã được hiển thị bên trong hàm _deductInventoryFromWebOrder
        setState(() => _isConfirming = false);
        return;
      }
      // ✨ KẾT THÚC BƯỚC MỚI ✨

      final newOrderRef =
          dbRef.child('nguoidung/${user!.uid}/donhang/saved/$newOrderId');
      final snapshot = await newOrderRef.get();
      if (snapshot.exists) {
        throw Exception(
            'Số HĐ "$newOrderId" đã tồn tại. Vui lòng xóa đơn web và đặt lại.');
      }

      final Map<String, dynamic> privateOrderData = {
        'orderId': newOrderId,
        'orderDate': originalOrderData['timestamp'],
        'customerInfo': newCustomerInfo,
        'notes': finalNotes,
        'items': secureItems.map((e) => e.toMap()).toList(),
        'status': 'saved',
        'total': totalFromWeb,
        'discount': discount,
        'shippingCost': shippingCost,
        'createdBy': 'WebCustomer',
        'employeeId': '',
        'savedAt': ServerValue.timestamp,
      };

      await newOrderRef.set(privateOrderData);
      await dbRef.child('website_data/${user!.uid}/orders/$newOrderId').remove();
      
      // ✨ SỬA LỖI 1: Bỏ "await"
      Navigator.of(dialogContext).pop();

      CustomNotificationService.show(
        context,
        message:
            'Đã xác nhận và chuyển đơn hàng "$newOrderId" vào mục "Đã lưu"',
      );
    } catch (e) {
      CustomNotificationService.show(
        context,
        message: 'Lỗi khi xác nhận đơn: $e',
        textColor: Colors.red,
        duration: const Duration(milliseconds: 3000),
      );
    } finally {
      // ✨ SỬA LỖI 2: Trì hoãn 300ms để chờ dialog đóng (hoàn tất animation)
      // trước khi gọi setState() để tránh lỗi.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) { // Luôn kiểm tra 'mounted' trước khi gọi setState
          setState(() => _isConfirming = false);
          _shippingCostController.clear();
          _discountController.clear();
        }
      });
    }
  }

// --- HÀM XÓA ĐƠN LẺ (✨ ĐÃ SỬA LỖI) ---
  Future<void> _deleteOrder(BuildContext dialogContext, String orderId) async {
    try {
      await dbRef.child('website_data/${user!.uid}/orders/$orderId').remove();
      
      // ✨ SỬA LỖI: Bỏ "await"
      Navigator.of(dialogContext).pop();
      
      CustomNotificationService.show(
        context,
        message: 'Đã xóa đơn hàng',
        textColor: Colors.orange.shade800,
      );
    } catch (e) {
      CustomNotificationService.show(
        context,
        message: 'Lỗi khi xóa đơn: $e',
        textColor: Colors.red,
        duration: const Duration(milliseconds: 3000),
      );
    }
    // Hàm này không có finally/setState nên không cần delay
  }

  // --- HÀM XÓA NHIỀU ĐƠN (Không đổi) ---
  Future<void> _deleteSelectedOrders() async {
    if (user == null || _selectedOrderIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận Xóa'),
        content: Text(
            'Bạn có chắc muốn xóa ${_selectedOrderIds.length} đơn hàng đã chọn không?'),
        actions: [
          TextButton(
            child: const Text('Hủy'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      Map<String, dynamic> updates = {};
      for (String orderId in _selectedOrderIds) {
        updates['website_data/${user!.uid}/orders/$orderId'] = null;
      }
      await dbRef.update(updates);

      CustomNotificationService.show(
        context,
        message: 'Đã xóa ${_selectedOrderIds.length} đơn hàng.',
        textColor: Colors.green,
      );
    } catch (e) {
      CustomNotificationService.show(
        context,
        message: 'Lỗi khi xóa: $e',
        textColor: Colors.red,
        duration: const Duration(milliseconds: 3000),
      );
    } finally {
      setState(() {
        _isSelectionMode = false;
        _selectedOrderIds.clear();
      });
    }
  }

  // --- CÁC HÀM BUILD GIAO DIỆN (Không đổi) ---
  Widget _buildProductRow(Map<String, dynamic> item) {
    final double price = (item['giaBan'] as num?)?.toDouble() ?? 0.0;
    final int qty = (item['quantity'] as num?)?.toInt() ?? 0;
    final double total = price * qty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item['tenSP'] ?? 'SP',
              style:
                  GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${FormatCurrency.format(price)} x $qty',
              textAlign: TextAlign.right,
              style: GoogleFonts.roboto(
                  fontSize: 12, color: const Color.fromARGB(255, 87, 87, 87)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              FormatCurrency.format(total),
              textAlign: TextAlign.right,
              style:
                  GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required List<Widget> children,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEditableDetailRow({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  onChanged: onChanged,
                  style: GoogleFonts.roboto(fontSize: 14),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide:
                          BorderSide(color: Colors.blue.shade700, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'Tên sản phẩm',
              style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Đ.Giá x SL',
              textAlign: TextAlign.right,
              style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'T.Tiền',
              textAlign: TextAlign.right,
              style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsDialog(String orderId, Map<String, dynamic> orderData) {
    final customerInfo =
        Map<String, dynamic>.from(orderData['customerInfo'] ?? {});
    final items = (orderData['items'] as List<dynamic>? ?? []);
    final double totalAmount =
        (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;

    final _nameController =
        TextEditingController(text: customerInfo['name']?.toString() ?? '');
    final _phoneController =
        TextEditingController(text: customerInfo['phone']?.toString() ?? '');
    final _emailController =
        TextEditingController(text: customerInfo['email']?.toString() ?? '');
    final _addressController =
        TextEditingController(text: customerInfo['address']?.toString() ?? '');
    final _notesController =
        TextEditingController(text: customerInfo['notes']?.toString() ?? '');

    _shippingCostController.text = '0';
    _discountController.text = '0';

    double currentShipping = 0.0;
    double currentDiscount = 0.0;
    double finalTotal = totalAmount + currentShipping - currentDiscount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          void updateTotal() {
            currentShipping =
                double.tryParse(_shippingCostController.text) ?? 0.0;
            currentDiscount = double.tryParse(_discountController.text) ?? 0.0;
            setStateDialog(() {
              finalTotal = totalAmount + currentShipping - currentDiscount;
            });
          }

          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.grey.shade100,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade700,
                          Colors.orange.shade900
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.download_for_offline,
                            color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Chi tiết Đơn hàng MỚI',
                            style: GoogleFonts.quicksand(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _isConfirming
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                        )
                      ],
                    ),
                  ),

                  // Nội dung Scrollable
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ID Web (với sao chép)
                            Row(
                              children: [
                                Text(
                                  'ID Web: $orderId',
                                  style: GoogleFonts.roboto(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color.fromARGB(
                                          255, 68, 68, 68)),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: orderId));
                                    CustomNotificationService.show(
                                      context,
                                      message: 'Đã sao chép mã đơn hàng',
                                      textColor: Colors.blue.shade800,
                                      duration:
                                          const Duration(milliseconds: 1500),
                                    );
                                  },
                                  child: Icon(
                                    Icons.content_copy_outlined,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // KHUNG 1: Thông tin khách hàng
                            _buildSectionContainer(
                              title: "Thông tin khách hàng",
                              icon: Icons.person_outline,
                              children: [
                                _buildEditableDetailRow(
                                  controller: _nameController,
                                  label: 'Tên khách hàng',
                                  icon: Icons.person_pin_outlined,
                                ),
                                _buildEditableDetailRow(
                                  controller: _phoneController,
                                  label: 'Số điện thoại',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                _buildEditableDetailRow(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                _buildEditableDetailRow(
                                  controller: _addressController,
                                  label: 'Địa chỉ',
                                  icon: Icons.location_on_outlined,
                                ),
                                _buildEditableDetailRow(
                                  controller: _notesController,
                                  label: 'Ghi chú (từ web)',
                                  icon: Icons.note_outlined,
                                  maxLines: 1,
                                ),
                              ],
                            ),

                            // KHUNG 2: Danh sách sản phẩm
                            _buildSectionContainer(
                              title: "Danh sách sản phẩm",
                              icon: Icons.shopping_basket_outlined,
                              children: [
                                _buildProductListHeader(),
                                const Divider(height: 8),
                                ...items.map((item) => _buildProductRow(
                                    Map<String, dynamic>.from(item))),
                              ],
                            ),

                            // KHUNG 3: Tài chính
                            _buildSectionContainer(
                              title: "Tài chính & Xác nhận",
                              icon: Icons.monetization_on_outlined,
                              children: [
                                _buildDetailRow(
                                  'Tổng tiền hàng (từ web):',
                                  FormatCurrency.format(totalAmount),
                                  Icons.receipt_long_outlined,
                                  isBold: true,
                                ),
                                const Divider(height: 16),
                                _buildEditableDetailRow(
                                  controller: _shippingCostController,
                                  label: 'Phí vận chuyển',
                                  icon: Icons.local_shipping_outlined,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) => updateTotal(),
                                ),
                                _buildEditableDetailRow(
                                  controller: _discountController,
                                  label: 'Giảm giá',
                                  icon: Icons.discount_outlined,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) => updateTotal(),
                                ),
                                const Divider(
                                    height: 20,
                                    thickness: 1.5,
                                    color: Colors.black87),
                                _buildDetailRow(
                                  'TỔNG THANH TOÁN:',
                                  FormatCurrency.format(finalTotal),
                                  Icons.payment_outlined,
                                  isBold: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Nút Hành động
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                            top: BorderSide(color: Colors.grey.shade200)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5))
                        ]),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed: _isConfirming
                              ? null
                              : () => _deleteOrder(dialogContext, orderId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Xóa đơn'),
                        ),
                        ElevatedButton(
                          onPressed: _isConfirming
                              ? null
                              : () {
                                  final Map<String, String> editedInfo = {
                                    'name': _nameController.text,
                                    'phone': _phoneController.text,
                                    'email': _emailController.text,
                                    'address': _addressController.text,
                                    'notes': _notesController.text,
                                  };
                                  String finalNotes = _notesController.text;

                                  _confirmOrder(
                                      dialogContext,
                                      orderId,
                                      orderData,
                                      editedInfo,
                                      finalNotes,
                                      double.tryParse(
                                              _shippingCostController.text) ??
                                          0.0,
                                      double.tryParse(
                                              _discountController.text) ??
                                          0.0);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: _isConfirming
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Xác nhận chuyển'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    ).whenComplete(() {
      _nameController.dispose();
      _phoneController.dispose();
      _emailController.dispose();
      _addressController.dispose();
      _notesController.dispose();
    });
  }

  // Dialog chỉ xem cho Tab 2 & 3
  void _showReadOnlyOrderDetails(OrderData order) {
    String employeeName = 'Không có';
    if (order.employeeId.isNotEmpty) {
      final employee = _allEmployees.firstWhere(
        (emp) => emp.id == order.employeeId,
        orElse: () =>
            const NhanVien(id: '', ten: 'Không tìm thấy', ma: '', timestamp: 0),
      );
      employeeName = employee.ten;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chi tiết đơn hàng ${order.orderId}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDetailSection(
                        title: 'Thông tin đơn hàng',
                        children: [
                          _buildDetailRow(
                              'Ngày đặt',
                              DateFormat('dd/MM/yyyy HH:mm')
                                  .format(order.orderDate),
                              Icons.calendar_today),
                          _buildDetailRow(
                              'Trạng thái',
                              _getOrderStatusDisplayName(order.status),
                              Icons.info),
                          if (order.employeeId.isNotEmpty)
                            _buildDetailRow(
                                'Nhân viên bán', employeeName, Icons.badge),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailSection(
                        title: 'Thông tin khách hàng',
                        children: [
                          _buildDetailRow('Khách hàng',
                              order.displayCustomerName, Icons.person),
                          _buildDetailRow(
                              'SĐT', order.displayCustomerPhone, Icons.phone),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailSection(
                        title: 'Danh sách sản phẩm',
                        children: order.items.asMap().entries.map((entry) {
                          int idx = entry.key;
                          OrderItem item = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              '${idx + 1}. ${item.name}\n   Số lượng: ${item.quantity} ${item.unit}   Đơn giá: ${FormatCurrency.format(item.unitPrice)}\n      Thành tiền: ${FormatCurrency.format(item.unitPrice * item.quantity)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailSection(
                        title: 'Tổng hợp tài chính',
                        children: [
                          _buildDetailRow(
                              'Tổng tiền hàng',
                              FormatCurrency.format(order.items.fold(
                                  0.0,
                                  (sum, item) =>
                                      sum + item.unitPrice * item.quantity)),
                              Icons.attach_money_outlined),
                          if (order.shippingCost > 0)
                            _buildDetailRow(
                                'Phí vận chuyển',
                                FormatCurrency.format(order.shippingCost),
                                Icons.local_shipping_outlined),
                          if (order.discount > 0)
                            _buildDetailRow(
                                'Giảm giá',
                                FormatCurrency.format(order.discount),
                                Icons.discount_outlined),
                          _buildDetailRow(
                            'Tổng thanh toán',
                            FormatCurrency.format(order.totalAmount),
                            Icons.payment_outlined,
                            isBold: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (order.notes.isNotEmpty)
                        _buildDetailSection(
                          title: 'Ghi chú',
                          children: [
                            Text(
                              order.notes,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      if (order.savedAt != null) ...[
                        const SizedBox(height: 7),
                        _buildDetailSection(
                          title: 'Thông tin cập nhật',
                          children: [
                            _buildDetailRow(
                              'Lần cuối cập nhật',
                              DateFormat('dd/MM/yyyy HH:mm').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      order.savedAt!)),
                              Icons.update_outlined,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Nút Đóng
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border(top: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Hàm xây dựng danh sách cho Tab 2 & 3
  Widget _buildReadOnlyOrderList(
      List<OrderData> orders, bool isLoading, String emptyMessage) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return Center(
          child: Text(emptyMessage,
              style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isSaved = order.status == OrderStatus.saved;

        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSaved ? Colors.blue.shade100 : Colors.green.shade100,
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: CircleAvatar(
              backgroundColor:
                  isSaved ? Colors.blue.shade100 : Colors.green.shade100,
              child: Icon(
                isSaved
                    ? Icons.inventory_2_outlined
                    : Icons.check_circle_outline,
                color: isSaved ? Colors.blue.shade700 : Colors.green.shade700,
              ),
            ),
            title: Text(
              order.displayCustomerName,
              style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SĐT: ${order.displayCustomerPhone}',
                  style: GoogleFonts.roboto(
                      color: Colors.grey.shade700, fontSize: 14),
                ),
                Text(
                  'HĐ: ${order.orderId}',
                  style: GoogleFonts.roboto(
                      color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            trailing: Text(
              FormatCurrency.format(order.totalAmount),
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSaved ? Colors.blue.shade800 : Colors.green.shade800,
              ),
            ),
            onTap: () {
              _showReadOnlyOrderDetails(order);
            },
          ),
        );
      },
    );
  }

  // Helpers sao chép từ donhang.dart
  Widget _buildDetailSection(
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: isBold ? Colors.red.shade700 : null,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getOrderStatusDisplayName(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return 'Đơn nháp';
      case OrderStatus.saved:
        return 'Đơn đã lưu';
      case OrderStatus.completed:
        return 'Đơn hoàn tất';
    }
  }

  // --- HÀM BUILD CHÍNH ---
  @override
  Widget build(BuildContext ctxt) {
    final sortedWebOrders = _webOrders.entries.toList()
      ..sort((a, b) =>
          (b.value['timestamp'] ?? 0).compareTo(a.value['timestamp'] ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(
            _isSelectionMode
                ? 'Đã chọn ${_selectedOrderIds.length}'
                : 'Đơn hàng Website',
            style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold, color: Colors.white)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: _buildAppBarActions(),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blue.shade100,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          labelStyle: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          unselectedLabelStyle:
              GoogleFonts.quicksand(fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: 'Đơn hàng mới (${sortedWebOrders.length})'),
            Tab(text: 'Đã lưu (${_savedOrders.length})'),
            Tab(text: 'Hoàn tất (${_completedOrders.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- TAB 1: ĐƠN HÀNG MỚI ---
          _isLoadingWebOrders
              ? const Center(child: CircularProgressIndicator())
              : sortedWebOrders.isEmpty
                  ? Center(
                      child: Text('Không có đơn hàng mới nào từ website.',
                          style: GoogleFonts.roboto(
                              fontSize: 16, color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      itemCount: sortedWebOrders.length,
                      itemBuilder: (context, index) {
                        final orderEntry = sortedWebOrders[index];
                        final orderId = orderEntry.key;
                        final orderData =
                            Map<String, dynamic>.from(orderEntry.value as Map);

                        final customerInfo = Map<String, dynamic>.from(
                            orderData['customerInfo'] ?? {});
                        final totalAmount =
                            (orderData['totalAmount'] as num?)?.toDouble() ??
                                0.0;

                        final bool isSelected =
                            _selectedOrderIds.contains(orderId);

                        return Card(
                          elevation: 1.5,
                          margin: const EdgeInsets.symmetric(vertical: 5.0),
                          color: isSelected ? Colors.blue.shade50 : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.blue.shade300
                                  : Colors.orange.shade100,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            leading: _isSelectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      _toggleOrderItemSelection(orderId);
                                    },
                                  )
                                : CircleAvatar(
                                    backgroundColor: Colors.orange.shade100,
                                    child: Icon(
                                      Icons.download,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                            title: Text(
                              customerInfo['name']?.toString() ??
                                  'Khách vãng lai',
                              style: GoogleFonts.quicksand(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.orange.shade900),
                            ),
                            subtitle: Text(
                              customerInfo['phone']?.toString() ?? 'N/A',
                              style: GoogleFonts.roboto(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                            trailing: Text(
                              FormatCurrency.format(totalAmount),
                              style: GoogleFonts.roboto(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red.shade700,
                              ),
                            ),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleOrderItemSelection(orderId);
                              } else {
                                _showOrderDetailsDialog(orderId, orderData);
                              }
                            },
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                _toggleSelectionMode(orderId);
                              }
                            },
                          ),
                        );
                      },
                    ),

          // --- TAB 2: ĐÃ LƯU (READ-ONLY) ---
          _buildReadOnlyOrderList(_savedOrders, _isLoadingSavedOrders,
              'Chưa có đơn hàng nào được lưu.'),

          // --- TAB 3: HOÀN TẤT (READ-ONLY) ---
          _buildReadOnlyOrderList(_completedOrders, _isLoadingCompletedOrders,
              'Chưa có đơn hàng nào hoàn tất.'),
        ],
      ),
    );
  }
}
