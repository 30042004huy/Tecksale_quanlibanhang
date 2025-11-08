import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/donhang_model.dart';
import 'taohoadon.dart';
import 'taodon.dart';
import 'suadon.dart';
import 'nhanvien.dart';
import '../models/nhanvien_model.dart'; // Hoặc nếu dùng từ nhanvien.dart, import 'nhanvien.dart';
import '../services/custom_notification_service.dart';


// DÁN VÀO ĐẦU FILE DONHANG.DART
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
        timestamp: map['timestamp'] is int ? map['timestamp'] : DateTime.now().millisecondsSinceEpoch,
      );
}
enum DisplayMode { large, small }


class DonHangScreen extends StatefulWidget {
  final OrderStatus? initialStatus;

  const DonHangScreen({Key? key, this.initialStatus}) : super(key: key);

  @override
  State<DonHangScreen> createState() => _DonHangScreenState();
}

class _DonHangScreenState extends State<DonHangScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Completer<void> _initialLoadCompleter = Completer<void>();
  late Future<void> _initialLoadFuture;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String? _uid;
  List<NhanVien> _allEmployees = [];
  String _selectedEmployeeId = 'all'; // 'all' là giá trị đại diện cho "Tất cả"
  Map<OrderStatus, List<OrderData>> _categorizedOrders = {};

  bool _isLoading = true;
  String? _selectedOrderIdForActions;
  Set<String> _selectedOrderIds = {};
  DisplayMode _displayMode = DisplayMode.large;
  bool _isSelectionMode = false;

  final Map<OrderStatus, StreamSubscription<DatabaseEvent>> _orderListeners = {};

  // Thêm vào lớp _DonHangScreenState
Future<void> _saveDisplayMode() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('displayMode', _displayMode.toString());
}

Future<void> _loadDisplayMode() async {
  final prefs = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('displayMode');
  if (savedMode != null) {
    setState(() {
      _displayMode = savedMode == DisplayMode.large.toString() ? DisplayMode.large : DisplayMode.small;
    });
  }
}
Future<void> _loadEmployees() async {
  if (_uid == null) return;
  try {
    final snapshot = await _dbRef.child('nguoidung/$_uid/nhanvien').get();
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final employees = data.entries.map((e) => NhanVien.fromMap(e.key, e.value as Map)).toList();
      employees.sort((a, b) => a.ten.compareTo(b.ten)); // Sắp xếp theo tên cho đẹp

      setState(() {
        _allEmployees = [
          // Tạo một nhân viên "ảo" để đại diện cho lựa chọn "Tất cả"
          const NhanVien(id: 'all', ten: 'Tất cả', ma: '', timestamp: 0),
          ...employees
        ];
      });
    } else {
      // Nếu không có nhân viên nào, vẫn hiển thị lựa chọn "Tất cả"
      setState(() {
        _allEmployees = [const NhanVien(id: 'all', ten: 'Tất cả', ma: '', timestamp: 0)];
      });
    }
  } catch (e) {
    print("Lỗi khi tải danh sách nhân viên: $e");
    // Đảm bảo vẫn có lựa chọn mặc định
    setState(() {
       _allEmployees = [const NhanVien(id: 'all', ten: 'Tất cả', ma: '', timestamp: 0)];
    });
  }
}

@override
void initState() {
  super.initState();
  _initialLoadFuture = _initialLoadCompleter.future; // THÊM DÒNG NÀY
  int initialIndex = 1; // Mặc định là tab Nháp
  if (widget.initialStatus == OrderStatus.saved) {
    initialIndex = 0; // Tab Đã lưu
  } else if (widget.initialStatus == OrderStatus.completed) {
    initialIndex = 2; // Tab Hoàn tất
  }
  _tabController = TabController(
    initialIndex: initialIndex,
    length: OrderStatus.values.length,
    vsync: this,
  );
  _tabController.addListener(_handleTabSelection);
  _searchController.addListener(_filterOrders);
  _initializeFirebaseAndLoadOrders();
  _loadDisplayMode();
  _loadEmployees(); // <-- THÊM DÒNG NÀY
}

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.removeListener(_filterOrders);
    _searchController.dispose();
    _cancelFirebaseListeners();
    super.dispose();
  }

  void _handleTabSelection() {
     {
      _filterOrders();
      setState(() {
        _selectedOrderIdForActions = null;
        _selectedOrderIds.clear();
        _isSelectionMode = false;
      });
    }
  }

  void _cancelFirebaseListeners() {
    _orderListeners.forEach((status, subscription) {
      subscription.cancel();
    });
    _orderListeners.clear();
  }

Future<void> _initializeFirebaseAndLoadOrders() async {
  _uid = _auth.currentUser?.uid;
  if (_uid == null) {
    _showErrorDialog('Bạn cần đăng nhập để xem đơn hàng.');
    if (!_initialLoadCompleter.isCompleted) {
      _initialLoadCompleter.completeError(Exception('User not logged in'));
    }
    return;
  }
  _loadEmployees(); // <-- THÊM DÒNG NÀY VÀO ĐÂY NỮA
  _cancelFirebaseListeners();
  
  // Đường dẫn tới thư mục cha 'donhang'
  final path = 'nguoidung/$_uid/donhang';

  // Chỉ cần MỘT stream listener duy nhất
  final streamSubscription = _dbRef.child(path).onValue.listen((event) {
// TẠM THỜI LƯU TẤT CẢ VÀO MỘT DANH SÁCH
      List<OrderData> allFetchedOrders = [];
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> statuses = event.snapshot.value as Map<dynamic, dynamic>;
        statuses.forEach((statusKey, ordersMap) {
          final Map<dynamic, dynamic> orders = ordersMap as Map<dynamic, dynamic>;
          orders.forEach((key, value) {
            try {
              final orderData = OrderData.fromMap(Map<String, dynamic>.from(value));
              allFetchedOrders.add(orderData);
            } catch (e) {
              print('ERROR: Lỗi khi phân tích dữ liệu đơn hàng $key: $e');
            }
          });
        });
      }

            // **PHẦN QUAN TRỌNG NHẤT: PHÂN LOẠI VÀ SẮP XẾP TRƯỚC**
      _categorizedOrders.clear(); // Xóa dữ liệu phân loại cũ
      for (var status in OrderStatus.values) {
          // 1. Lọc ra danh sách con theo từng trạng thái
          var listForStatus = allFetchedOrders.where((order) => order.status == status).toList();
          // 2. Sắp xếp danh sách con này
          listForStatus.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          // 3. Lưu vào "rổ" tương ứng
          _categorizedOrders[status] = listForStatus;
      }

      // Sau khi thêm tất cả đơn hàng, gọi setState để cập nhật UI
      setState(() {
        _filterOrders();
      });
    

    // Báo hiệu rằng lần tải dữ liệu đầu tiên đã hoàn tất
    if (!_initialLoadCompleter.isCompleted) {
      _initialLoadCompleter.complete();
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }, onError: (error) {
    if (!_initialLoadCompleter.isCompleted) {
      _initialLoadCompleter.completeError(error);
    }
  });

  // Chỉ lưu lại một listener này
  _orderListeners[OrderStatus.draft] = streamSubscription; // Lưu tạm vào một key bất kỳ để có thể hủy
}


void _filterOrders() {
  // Chỉ cần gọi setState để kích hoạt việc build lại widget.
  // Logic lọc sẽ được thực hiện trực tiếp và tức thì trong hàm build.
  setState(() {});
}


  void _navigateToSuaDonScreen(OrderData order) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TaoDonScreen(orderToEdit: order),
    ),
  ).then((_) => _filterOrders());  // Refresh sau sửa
}
  
  Future<void> _restoreInventory(OrderData order) async {
    try {
      for (var item in order.items) {
        final productRef = _dbRef.child('nguoidung/$_uid/sanpham/${item.productId}');
        final snapshot = await productRef.get();
        if (snapshot.exists) {
          final productData = Map<String, dynamic>.from(snapshot.value as Map);
          final currentStock = (productData['tonKho'] as int?) ?? 0;
          await productRef.update({
            'tonKho': currentStock + item.quantity,
          });
        }
      }
    } catch (e) {
      print('Lỗi khi hoàn lại tồn kho: $e');
      _showErrorDialog('Lỗi khi hoàn lại tồn kho: $e');
    }
  }

Future<void> _deleteOrders(Set<String> orderIdsToDelete) async {
  if (orderIdsToDelete.isEmpty) return;

  // ✨ SỬA LỖI 1: Lưu lại số lượng cần xóa vào một biến
  final int countToDelete = orderIdsToDelete.length;

  final bool confirm = await _showConfirmDialog(
    'Xác nhận xóa',
    'Bạn có chắc chắn muốn xóa $countToDelete đơn hàng đã chọn?',
  );
  if (!confirm) return;

  setState(() { _isLoading = true; });

  final Map<String, dynamic> multiPathUpdates = {};
  final List<OrderData> ordersToRestoreInventory = [];
  int successfulDeletes = 0; // Biến đếm số lần xóa thành công

  try {
    for (final orderId in orderIdsToDelete) {
      OrderData? order;
      OrderStatus? orderStatus;

      for (final entry in _categorizedOrders.entries) {
        try {
          order = entry.value.firstWhere((o) => o.orderId == orderId);
          orderStatus = entry.key;
          break;
        } catch (e) {
          // Bỏ qua
        }
      }

      if (order != null && orderStatus != null) {
        if (order.status == OrderStatus.saved) {
          ordersToRestoreInventory.add(order);
        }

        final String statusPath = orderStatus.toString().split('.').last;
        final String fullPath = '/nguoidung/$_uid/donhang/$statusPath/$orderId';
        multiPathUpdates[fullPath] = null;
        successfulDeletes++; // Tăng biến đếm
      }
    }

    if (ordersToRestoreInventory.isNotEmpty) {
      await Future.wait(ordersToRestoreInventory.map((o) => _restoreInventory(o)));
    }

    if (multiPathUpdates.isNotEmpty) {
      await _dbRef.root.update(multiPathUpdates);
    }

    setState(() {
      _selectedOrderIds.clear();
      _isSelectionMode = false;
      _selectedOrderIdForActions = null;
    });

    // ✨ SỬA LỖI 2: Sử dụng CustomNotificationService và biến đếm đã lưu
    if (mounted) {
      CustomNotificationService.show(
        context,
        message: 'Đã xóa $successfulDeletes đơn hàng thành công!',
        // Bạn có thể tùy chỉnh màu sắc nếu muốn
        // backgroundColor: Colors.white,
        // textColor: Colors.green,
      );
    }

  } catch (e) {
    // ✨ SỬA LỖI 3: Sử dụng CustomNotificationService cho thông báo lỗi
    if (mounted) {
       CustomNotificationService.show(
        context,
        message: 'Lỗi khi xóa đơn hàng: $e',
        textColor: Colors.red, // Đổi màu chữ thành đỏ cho lỗi
      );
    }
  } finally {
    setState(() { _isLoading = false; });
  }
}

Future<void> _updateOrderStatus(OrderData order, OrderStatus newStatus) async {
  // 1. Hiển thị dialog xác nhận
  final bool confirm = await _showConfirmDialog(
    'Xác nhận hoàn tất',
    'Bạn có chắc chắn muốn hoàn tất đơn hàng này?',
  );
  if (!confirm) return;

  // 2. Bắt đầu trạng thái tải
  setState(() {
    _isLoading = true;
  });

  String oldStatusPath = order.status.toString().split('.').last;
  String newStatusPath = newStatus.toString().split('.').last;

  try {
    // 3. Thực hiện các thao tác cập nhật trên Firebase
    await _dbRef.child('nguoidung/$_uid/donhang/$oldStatusPath/${order.orderId}').remove();
    final updatedOrder = order.copyWith(status: newStatus, savedAt: ServerValue.timestamp);
    await _dbRef.child('nguoidung/$_uid/donhang/$newStatusPath/${updatedOrder.orderId}').set(updatedOrder.toMap());

    // ✨ THAY ĐỔI CỐT LÕI BẮT ĐẦU TỪ ĐÂY ✨

    // 4. Đóng popup chi tiết đơn hàng lại
    if (mounted) {
      Navigator.of(context).pop();
    }

    // 5. Hiển thị thông báo tùy chỉnh thay vì dialog cũ
    if (mounted) {
      CustomNotificationService.show(
        context,
        message: 'Đã hoàn tất đơn hàng!',
        // Bạn có thể tùy chỉnh màu sắc nếu muốn, ví dụ:
        // textColor: Colors.green,
      );
    }
    
    // 6. Cập nhật trạng thái giao diện
    setState(() {
      _selectedOrderIdForActions = null;
      _selectedOrderIds.remove(order.orderId);
      if (_selectedOrderIds.isEmpty) {
        _isSelectionMode = false;
      }
    });

  } catch (e) {
    // Hiển thị lỗi bằng thông báo tùy chỉnh
    if (mounted) {
      CustomNotificationService.show(
        context,
        message: 'Lỗi khi cập nhật: $e',
        textColor: Colors.red,
      );
    }
  } finally {
    // 7. Kết thúc trạng thái tải
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

void _showOrderDetailsDialog(OrderData order) {
  // ✨ TÌM TÊN NHÂN VIÊN
  String employeeName = 'Không có'; // Giá trị mặc định
  if (order.employeeId.isNotEmpty) {
    // Dùng firstWhereOrNull để tránh lỗi nếu không tìm thấy
    final employee = _allEmployees.firstWhere(
      (emp) => emp.id == order.employeeId,
      // Trả về một NhanVien ảo nếu không tìm thấy để không bị lỗi
      orElse: () => const NhanVien(id: '', ten: 'Không tìm thấy', ma: '', timestamp: 0),
    );
    employeeName = employee.ten;
  }

  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // ... (Phần header của dialog giữ nguyên)
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
            _buildDetailRow('Ngày đặt', DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate), Icons.calendar_today),
            _buildDetailRow('Trạng thái', _getOrderStatusDisplayName(order.status), Icons.info),
            if (order.employeeId.isNotEmpty)
              _buildDetailRow('Nhân viên bán', employeeName, Icons.badge),
          ],
        ),
        const SizedBox(height: 12),
        _buildDetailSection(
          title: 'Thông tin khách hàng',
          children: [
            _buildDetailRow('Khách hàng', order.displayCustomerName, Icons.person), // SỬA: getter
            _buildDetailRow('SĐT', order.displayCustomerPhone, Icons.phone), // SỬA: getter

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
                            '${idx + 1}. ${item.name}\n   Số lượng: ${item.quantity} ${item.unit}   Đơn giá: ${FormatCurrency.formatCurrency(item.unitPrice)}\n      Thành tiền: ${FormatCurrency.formatCurrency(item.unitPrice * item.quantity)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailSection(
                      title: 'Tổng hợp tài chính',
                      children: [
                        _buildDetailRow('Tổng tiền hàng', FormatCurrency.formatCurrency(order.items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity)), Icons.attach_money),
                        if (order.shippingCost > 0)
                          _buildDetailRow('Phí vận chuyển', FormatCurrency.formatCurrency(order.shippingCost), Icons.local_shipping),
                        if (order.discount > 0)
                          _buildDetailRow('Giảm giá', FormatCurrency.formatCurrency(order.discount), Icons.discount),
                        _buildDetailRow(
                          'Tổng thanh toán',
                          FormatCurrency.formatCurrency(order.items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity) + order.shippingCost - order.discount),
                          Icons.payment,
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
                            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(order.savedAt)),
                            Icons.update,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.2),
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Wrap(
                    alignment: WrapAlignment.end, // Canh các nút về phía cuối
                    spacing: 10, // Khoảng cách giữa các nút
                    runSpacing: 10, // Khoảng cách giữa các hàng khi xuống dòng
                  children: [
                    ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black, // Màu chữ và icon
                            side: const BorderSide(color: Color.fromARGB(255, 235, 235, 235)), // Màu viền
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text('Đóng'),
                        ),
                    if (order.status == OrderStatus.saved) ...[
                      
                      if (order.status == OrderStatus.saved)
                      ElevatedButton.icon(
                        onPressed: () {
                          // Đóng popup hiện tại
                          Navigator.pop(context);
                          // Sau đó, chuyển đến trang sửa đơn hàng
                          _navigateToSuaDonScreen(order);
                        },  // Nút sửa cho saved
                        icon: const Icon(Icons.edit),
                        label: const Text('Sửa'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange,foregroundColor: Colors.white),
                      ),
  
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => _updateOrderStatus(order, OrderStatus.completed),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Text('Hoàn tất'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _navigateToTaoHoaDonScreen(order);
                          setState(() { _selectedOrderIdForActions = null; });
                        },
                        icon: const Icon(Icons.receipt, size: 18),
                        label: const Text('Hóa đơn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool isBold = false}) {
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
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade600, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Xác nhận'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Thành công',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade600, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Lỗi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  void _navigateToTaoHoaDonScreen(OrderData order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaoHoaDonScreen(orderData: order),
      ),
    );
  }

  void _navigateToTaoDonScreen(OrderData order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaoDonScreen(orderToEdit: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đơn hàng',),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        

        elevation: 0,
        actions: [
          IconButton(
  icon: Icon(_selectedOrderIds.isEmpty ? Icons.check_box : Icons.delete),
  onPressed: _isLoading
      ? null
      : () {
          // THAY THẾ PHẦN LOGIC CŨ BẰNG ĐOẠN NÀY
          if (_selectedOrderIds.isNotEmpty) {
            _deleteOrders(_selectedOrderIds); // <-- GỌI HÀM MỚI
          } else {
            setState(() {
              _isSelectionMode = !_isSelectionMode;
              if (!_isSelectionMode) {
                _selectedOrderIds.clear();
                _selectedOrderIdForActions = null;
              }
            });
          }
        },
  tooltip: _selectedOrderIds.isNotEmpty ? 'Xóa các đơn đã chọn' : 'Kích hoạt chế độ chọn',
),
          IconButton(
            icon: Icon(_displayMode == DisplayMode.large ? Icons.view_list : Icons.view_comfortable),
            onPressed: () {
              setState(() {
                _displayMode = _displayMode == DisplayMode.large ? DisplayMode.small : DisplayMode.large;
                _selectedOrderIdForActions = null;
                _selectedOrderIds.clear();
                _isSelectionMode = false;
              });
              _saveDisplayMode(); // Thêm dòng này vào đây
            },
            tooltip: _displayMode == DisplayMode.large ? 'Chuyển sang giao diện nhỏ' : 'Chuyển sang giao diện to',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blue.shade200,
          indicatorColor: Colors.white,
          tabs: OrderStatus.values.map((status) {
            return Tab(text: _getOrderStatusDisplayName(status));
          }).toList(),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _selectedOrderIdForActions = null;
          });
        },
        child: Column(
          children: [
            // DÁN ĐOẠN CODE NÀY VÀO THAY THẾ CHO PADDING CŨ
Padding(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), // Điều chỉnh padding
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // 1. Ô TÌM KIẾM (ĐƯỢC BỌC TRONG EXPANDED)
      Expanded(
        child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 12), // Giảm cỡ chữ một chút
                decoration: InputDecoration(
                  labelText: 'Tìm kiếm',
                  prefixIcon: const Icon(Icons.search, color: Colors.blueAccent, size:20),
                  isDense: true, 
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0,),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
                  ),
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  labelStyle: TextStyle(color: Colors.blue.shade700),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                ),
              ),
      ),
      const SizedBox(width: 5),

      // 2. ICON VÀ DROPDOWN CHỌN NHÂN VIÊN
      Container(
        height: 40, // THAY ĐỔI: Đặt chiều cao cố định để đồng bộ với TextField
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedEmployeeId,
            icon: const Icon(Icons.person_search, color: Colors.blueAccent),
            isDense: true,
            items: _allEmployees.map((NhanVien nv) {
              return DropdownMenuItem<String>(
                value: nv.id,
                child: Text(
                  nv.ten,
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedEmployeeId = newValue;
                  // setState() sẽ tự động build lại UI và áp dụng bộ lọc
                });
              }
            },
          ),
        ),
      ),
    ],
  ),
),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(
  child: TabBarView(
    controller: _tabController,
    // Tạo ra một view độc lập cho mỗi trạng thái
    children: OrderStatus.values.map((status) {
      
  // 1. Lấy danh sách gốc cho tab này
  final originalList = _categorizedOrders[status] ?? [];

  // 2. LỌC THEO NHÂN VIÊN ĐANG CHỌN (LOGIC MỚI)
  List<OrderData> employeeFilteredList;
  if (_selectedEmployeeId != 'all') {
      employeeFilteredList = originalList.where((order) => order.employeeId == _selectedEmployeeId).toList();
  } else {
      employeeFilteredList = originalList; // 'Tất cả' thì không lọc
  }

  // 3. Áp dụng logic tìm kiếm trên danh sách đã lọc theo nhân viên
  final String query = _searchController.text.toLowerCase();
  final List<OrderData> displayedList;
  if (query.isEmpty) {
    displayedList = employeeFilteredList;
  } else {
    displayedList = employeeFilteredList.where((order) { // Sửa 'originalList' thành 'employeeFilteredList'
      final matchesSearch = order.displayCustomerName.toLowerCase().contains(query) ||
          order.displayCustomerPhone.toLowerCase().contains(query) ||
          order.orderId.toLowerCase().contains(query);
      return matchesSearch;
    }).toList();
  }

  // 4. Build ListView với danh sách cuối cùng
  if (displayedList.isEmpty && !_isLoading) {
        return Center(
          child: Text(
            query.isEmpty
              ? 'Chưa có đơn hàng nào ở trạng thái "${_getOrderStatusDisplayName(status)}".'
              : 'Không tìm thấy đơn hàng nào khớp với tìm kiếm.',
            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        );
      }
      
      // 4. Build ListView với danh sách đã được lọc chính xác
      return ListView.builder(
        itemCount: displayedList.length,
        itemBuilder: (context, index) {
          // Giờ đây 'order' luôn là dữ liệu đúng của tab hiện tại
          final order = displayedList[index]; 
          
          // --- TOÀN BỘ CODE CỦA CARD HIỂN THỊ ĐƠN HÀNG GIỮ NGUYÊN ---
          final bool isSelected = _selectedOrderIdForActions == order.orderId;
          return Card(

                              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                              elevation: isSelected ? 10 : 6,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                                side: BorderSide(
                                  color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  if (_selectedOrderIdForActions != null) {
                                    setState(() {
                                      _selectedOrderIdForActions = null;
                                    });
                                  } else {
                                    _showOrderDetailsDialog(order);
                                  }
                                },
                                onLongPress: () {
                                  setState(() {
                                    _selectedOrderIdForActions = isSelected ? null : order.orderId;
                                  });
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      if (_isSelectionMode)
                                        Checkbox(
                                          value: _selectedOrderIds.contains(order.orderId),
                                          onChanged: (bool? value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedOrderIds.add(order.orderId);
                                              } else {
                                                _selectedOrderIds.remove(order.orderId);
                                              }
                                            });
                                          },
                                        ),
                                      Expanded(
                                        child: _displayMode == DisplayMode.large
                                            ? Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${index + 1}. Số HĐ: ${order.orderId}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                      color: Colors.blue.shade800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _buildInfoRow('Khách hàng:', order.displayCustomerName, Icons.person),
                                                  _buildInfoRow('SĐT:', order.displayCustomerPhone, Icons.phone),
                                                  _buildInfoRow(
                                                    'Tổng thanh toán:',
                                                    FormatCurrency.formatCurrency(
                                                      order.items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity) +
                                                          order.shippingCost -
                                                          order.discount,
                                                    ),
                                                    Icons.payment,
                                                    isTotal: true,
                                                  ),
                                                  _buildInfoRow('Ngày:', DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate), Icons.calendar_today),
                                                  if (order.status == OrderStatus.saved && !isSelected) ...[
                                                    const SizedBox(height: 12),
                                                    Align(
                                                      alignment: Alignment.bottomRight,
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          ElevatedButton.icon(
                                                            onPressed: () {
                                                              _navigateToTaoHoaDonScreen(order);
                                                              setState(() { _selectedOrderIdForActions = null; });
                                                            },
                                                            icon: const Icon(Icons.receipt, size: 18),
                                                            label: const Text('Hóa đơn'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.blue.shade600,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              elevation: 3,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          ElevatedButton.icon(
                                                            onPressed: _isLoading
                                                                ? null
                                                                : () {
                                                                    _updateOrderStatus(order, OrderStatus.completed);
                                                                    setState(() { _selectedOrderIdForActions = null; });
                                                                  },
                                                            icon: _isLoading
                                                                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                                                : const Icon(Icons.check_circle, size: 18),
                                                            label: const Text('Hoàn tất'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.green.shade600,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              elevation: 3,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  if (isSelected) ...[
                                                   
                                                    Align(
                                                      alignment: Alignment.bottomRight,
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                       ElevatedButton.icon(
                                                            onPressed: () {
                                                              _navigateToTaoHoaDonScreen(order);
                                                              setState(() { _selectedOrderIdForActions = null; });
                                                            },
                                                            icon: const Icon(Icons.receipt, size: 18),
                                                            label: const Text('Hóa đơn'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.blue.shade600,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              elevation: 3,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            ),
                                                          ),
                                                          
                                                          ElevatedButton.icon(
                                                            onPressed: _isLoading
                                                                ? null
                                                                : () {
                                              _deleteOrders({order.orderId}); // <-- GỌI HÀM MỚI VỚI MỘT SET CHỨA 1 ID
                                              setState(() { _selectedOrderIdForActions = null; });
                                                                  },
                                                            icon: const Icon(Icons.delete, size: 18),
                                                            label: const Text('Xóa'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red.shade600,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              elevation: 3,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  if (order.status == OrderStatus.completed && !isSelected)
                                                    Align(
                                                      alignment: Alignment.bottomRight,
                                                      child:Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                       ElevatedButton.icon(
                                                        onPressed: () => _showOrderDetailsDialog(order),
                                                        icon: const Icon(Icons.info, size: 18),
                                                        label: const Text('Xem thông tin'),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.grey.shade600,
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                          elevation: 3,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                        ),
                                                      ),
                                                     ],
                                                  ),
                                               ),

                                                  if (order.status == OrderStatus.draft && !isSelected)
                                                      Align(
                                                        alignment: Alignment.bottomRight,
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min, // Giúp Row chỉ chiếm không gian cần thiết
                                                          children: [
                                                            // Nút Xóa Đơn
                                                            ElevatedButton.icon(
                                                            onPressed: _isLoading
                                                                ? null
                                                                : () {
                                                                    _deleteOrders({order.orderId}); 
                                                                    setState(() { _selectedOrderIdForActions = null; });
                                                                  },
                                                            icon: const Icon(Icons.delete, size: 18),
                                                            label: const Text('Xóa'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red.shade600,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              elevation: 3,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            ),
                                                          ),
                                                        const SizedBox(width: 8), // Khoảng cách giữa hai nút
                                                        // Nút Sửa Đơn
                                                        ElevatedButton.icon(
                                                          onPressed: () {
                                                            _navigateToTaoDonScreen(order);
                                                            setState(() {
                                                              _selectedOrderIdForActions = null;
                                                            });
                                                          },
                                                          icon: const Icon(Icons.edit, size: 18),
                                                          label: const Text('Sửa đơn'),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.orange.shade600,
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                            elevation: 3,
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                    
                                                ],
                                              )
                                            : Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${index + 1}. Số HĐ: ${order.orderId}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.blue.shade800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Khách hàng: ${order.displayCustomerName}',
                                                    style: const TextStyle(fontSize: 14),
                                                    softWrap: true,
                                                  ),
                                                  Text(
                                                    'SĐT: ${order.displayCustomerPhone}',
                                                    style: const TextStyle(fontSize: 14),
                                                    softWrap: true,
                                                  ),
                                                  Text(
                                                    'Tổng thanh toán: ${FormatCurrency.formatCurrency(order.items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity) + order.shippingCost - order.discount)}',
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                                    softWrap: true,
                                                  ),
                                                  if (isSelected) ...[
                                                    
                                                    Align(
                                                      alignment: Alignment.bottomRight,
                                                      child: Wrap(
                                                        spacing: 8,
                                                        children: [
                                                          if (order.status == OrderStatus.saved) ...[
                                                            ElevatedButton.icon(
                                                              onPressed: () {
                                                                _navigateToTaoHoaDonScreen(order);
                                                                setState(() { _selectedOrderIdForActions = null; });
                                                              },
                                                              icon: const Icon(Icons.receipt, size: 18),
                                                              label: const Text('Hóa đơn'),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.blue.shade600,
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                elevation: 3,
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                              ),
                                                            ),
                                                            ElevatedButton.icon(
                                                              onPressed: _isLoading
                                                                  ? null
                                                                  : () {
                                                                      _updateOrderStatus(order, OrderStatus.completed);
                                                                      setState(() { _selectedOrderIdForActions = null; });
                                                                    },
                                                              icon: _isLoading
                                                                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                                                  : const Icon(Icons.check_circle, size: 18),
                                                              label: const Text('Hoàn tất'),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.green.shade600,
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                elevation: 3,
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                              ),
                                                            ),
                                                            ElevatedButton.icon(
                                                            onPressed: _isLoading
                                                                ? null
                                                                : () {
                                                                    _deleteOrders({order.orderId}); 
                                                                    setState(() { _selectedOrderIdForActions = null; });
                                                                  },
                                                            icon: const Icon(Icons.delete, size: 18),
                                                            label: const Text('Xóa'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red.shade600,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              elevation: 2,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            ),
                                                          ),
                                                          ],

                                                          
                                                          if (order.status == OrderStatus.completed)
                                                          ElevatedButton.icon(
                                                            onPressed: _isLoading
                                                                ? null
                                                                : () {
                                                                    _deleteOrders({order.orderId}); 
                                                                    setState(() { _selectedOrderIdForActions = null; });
                                                                  },
                                                            icon: const Icon(Icons.delete, size: 18),
                                                            label: const Text('Xóa'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red.shade600,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              elevation: 3,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            ),
                                                          ),
                                                          if (order.status == OrderStatus.completed)
                                                          ElevatedButton.icon(
                                                              onPressed: () {
                                                                _navigateToTaoHoaDonScreen(order);
                                                                setState(() { _selectedOrderIdForActions = null; });
                                                              },
                                                              icon: const Icon(Icons.receipt, size: 18),
                                                              label: const Text('Hóa đơn'),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.blue.shade600,
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                elevation: 3,
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                              ),
                                                            ),
                                                            
                                                            
                                                            
                                                          if (order.status == OrderStatus.draft)
                                                            ElevatedButton.icon(
                                                              onPressed: () {
                                                                _navigateToTaoDonScreen(order);
                                                                setState(() { _selectedOrderIdForActions = null; });
                                                              },
                                                              icon: const Icon(Icons.edit, size: 18),
                                                              label: const Text('Sửa đơn'),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.orange.shade600,
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                elevation: 3,
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                              ),
                                                            ),
                                                            if (order.status == OrderStatus.draft)
                                                            ElevatedButton.icon(
                                                            onPressed: _isLoading
                                                                ? null
                                                                : () {
                                                                   _deleteOrders({order.orderId}); 
                                                                    setState(() { _selectedOrderIdForActions = null; });
                                                                  },
                                                            icon: const Icon(Icons.delete, size: 18),
                                                            label: const Text('Xóa'),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red.shade600,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                              elevation: 3,
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                            ),
                                                          ),
                                                            
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}