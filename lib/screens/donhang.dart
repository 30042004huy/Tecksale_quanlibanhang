import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/donhang_model.dart';
import 'taohoadon.dart';
import 'taodon.dart';

enum DisplayMode { large, small }

class DonHangScreen extends StatefulWidget {
  const DonHangScreen({Key? key}) : super(key: key);

  @override
  State<DonHangScreen> createState() => _DonHangScreenState();
}

class _DonHangScreenState extends State<DonHangScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String? _uid;

  List<OrderData> _allOrders = [];
  List<OrderData> _filteredOrders = [];
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: OrderStatus.values.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _searchController.addListener(_filterOrders);
    _initializeFirebaseAndLoadOrders();
    _loadDisplayMode(); // Thêm dòng này vào đây
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
    if (_tabController.indexIsChanging) {
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
    setState(() {
      _isLoading = true;
    });

    _uid = _auth.currentUser?.uid;
    if (_uid == null) {
      _showErrorDialog('Bạn cần đăng nhập để xem đơn hàng.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _cancelFirebaseListeners();

    for (var status in OrderStatus.values) {
      await _loadOrders(status);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadOrders(OrderStatus status) async {
    String statusPath = status.toString().split('.').last;
    final path = 'nguoidung/$_uid/donhang/$statusPath';

    _dbRef.child(path).keepSynced(true);

    final streamSubscription = _dbRef.child(path).onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        List<OrderData> fetchedOrders = [];
        data.forEach((key, value) {
          try {
            final orderMap = Map<String, dynamic>.from(value);
            final orderData = OrderData.fromMap(orderMap);
            fetchedOrders.add(orderData);
          } catch (e) {
            print('ERROR: Lỗi khi phân tích dữ liệu đơn hàng $key: $e');
          }
        });

        setState(() {
          _allOrders.removeWhere((order) => order.status == status);
          _allOrders.addAll(fetchedOrders);
          _filterOrders();
        });
      } else {
        setState(() {
          _allOrders.removeWhere((order) => order.status == status);
          _filterOrders();
        });
      }
    }, onError: (error) {
      _showErrorDialog('Lỗi khi tải đơn hàng: $error');
      setState(() {
        _isLoading = false;
      });
    });

    _orderListeners[status] = streamSubscription;
  }

  void _filterOrders() {
    final String query = _searchController.text.toLowerCase();
    final OrderStatus currentTabStatus = OrderStatus.values[_tabController.index];

    setState(() {
      _filteredOrders = _allOrders.where((order) {
        final matchesStatus = order.status == currentTabStatus;
        if (query.isEmpty) {
          return matchesStatus;
        } else {
          final matchesSearch = order.customerName.toLowerCase().contains(query) ||
              order.customerPhone.toLowerCase().contains(query) ||
              order.orderId.toLowerCase().contains(query);
          return matchesStatus && matchesSearch;
        }
      }).toList();
      _filteredOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    });
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

  Future<void> _deleteOrder(String orderId, OrderStatus status) async {
    final bool confirm = await _showConfirmDialog('Xác nhận xóa', 'Bạn có chắc chắn muốn xóa đơn hàng này?');
    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    String statusPath = status.toString().split('.').last;
    final path = 'nguoidung/$_uid/donhang/$statusPath/$orderId';

    try {
      final order = _allOrders.firstWhere((o) => o.orderId == orderId);
      if (order.status == OrderStatus.saved) {
        await _restoreInventory(order);
      }
      await _dbRef.child(path).remove();
      _showSuccessDialog('Đơn hàng đã được xóa thành công!');
      setState(() {
        _selectedOrderIdForActions = null;
        _selectedOrderIds.remove(orderId);
      });
    } catch (e) {
      _showErrorDialog('Lỗi khi xóa đơn hàng: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSelectedOrders() async {
    if (_selectedOrderIds.isEmpty) return;

    final bool confirm = await _showConfirmDialog('Xác nhận xóa', 'Bạn có chắc chắn muốn xóa ${_selectedOrderIds.length} đơn hàng đã chọn?');
    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      for (String orderId in _selectedOrderIds) {
        final order = _allOrders.firstWhere((o) => o.orderId == orderId);
        if (order.status == OrderStatus.saved) {
          await _restoreInventory(order);
        }
        String statusPath = order.status.toString().split('.').last;
        final path = 'nguoidung/$_uid/donhang/$statusPath/$orderId';
        await _dbRef.child(path).remove();
      }
      _showSuccessDialog('Đã xóa ${_selectedOrderIds.length} đơn hàng thành công!');
      setState(() {
        _selectedOrderIdForActions = null;
        _selectedOrderIds.clear();
        _isSelectionMode = false;
      });
    } catch (e) {
      _showErrorDialog('Lỗi khi xóa các đơn hàng: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(OrderData order, OrderStatus newStatus) async {
    final bool confirm = await _showConfirmDialog('Xác nhận hoàn tất', 'Bạn có chắc chắn muốn hoàn tất đơn hàng này?');
    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    String oldStatusPath = order.status.toString().split('.').last;
    String newStatusPath = newStatus.toString().split('.').last;

    try {
      await _dbRef.child('nguoidung/$_uid/donhang/$oldStatusPath/${order.orderId}').remove();
      final updatedOrder = order.copyWith(status: newStatus, savedAt: ServerValue.timestamp);
      await _dbRef.child('nguoidung/$_uid/donhang/$newStatusPath/${updatedOrder.orderId}').set(updatedOrder.toMap());
      _showSuccessDialog('Đơn hàng đã được cập nhật trạng thái thành công!');
      setState(() {
        _selectedOrderIdForActions = null;
        _selectedOrderIds.remove(order.orderId);
        _isSelectionMode = false;
      });
    } catch (e) {
      _showErrorDialog('Lỗi khi cập nhật trạng thái đơn hàng: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showOrderDetailsDialog(OrderData order) {
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailSection(
                        title: 'Thông tin khách hàng',
                        children: [
                          _buildDetailRow('Khách hàng', order.customerName, Icons.person),
                          _buildDetailRow('SĐT', order.customerPhone, Icons.phone),
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
                      color: Colors.grey.withOpacity(0.2),
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng', style: TextStyle(color: Color.fromARGB(255, 57, 57, 57))),
                    ),

                  
                      const SizedBox(width: 10), 
                    if (order.status == OrderStatus.saved) ...[
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _navigateToTaoHoaDonScreen(order);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 0, 115, 255),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Text('Xem Hóa Đơn'),
                      ),
                      
                      const SizedBox(width: 10), 
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => _updateOrderStatus(order, OrderStatus.completed),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : const Text('Hoàn tất'),
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
        title: const Text('Quản lý đơn hàng'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_selectedOrderIds.isEmpty ? Icons.check_box : Icons.delete),
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      if (_selectedOrderIds.isNotEmpty) {
                        _deleteSelectedOrders();
                      } else {
                        _isSelectionMode = !_isSelectionMode;
                        if (!_isSelectionMode) {
                          _selectedOrderIds.clear();
                          _selectedOrderIdForActions = null;
                        }
                      }
                    });
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Tìm kiếm đơn hàng (SĐT, Tên KH, Số HĐ)',
                  prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2.0),
                  ),
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  labelStyle: TextStyle(color: Colors.blue.shade700),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                ),
              ),
            ),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: OrderStatus.values.map((status) {
                        final ordersForStatus = _filteredOrders.where((order) => order.status == status).toList();
                        if (ordersForStatus.isEmpty) {
                          return Center(
                            child: Text(
                              'Chưa có đơn hàng nào ở trạng thái "${_getOrderStatusDisplayName(status)}".',
                              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: ordersForStatus.length,
                          itemBuilder: (context, index) {
                            final order = ordersForStatus[index];
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
                                                  _buildInfoRow('Khách hàng:', order.customerName, Icons.person),
                                                  _buildInfoRow('SĐT:', order.customerPhone, Icons.phone),
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
                                                            label: const Text('Xem hóa đơn'),
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
                                                    const SizedBox(height: 8),
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
                                                            label: const Text('Xem hóa đơn'),
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
                                                                    _deleteOrder(order.orderId, order.status);
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
                                                      child: ElevatedButton.icon(
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
                                                    'Khách hàng: ${order.customerName}',
                                                    style: const TextStyle(fontSize: 14),
                                                    softWrap: true,
                                                  ),
                                                  Text(
                                                    'SĐT: ${order.customerPhone}',
                                                    style: const TextStyle(fontSize: 14),
                                                    softWrap: true,
                                                  ),
                                                  Text(
                                                    'Tổng thanh toán: ${FormatCurrency.formatCurrency(order.items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity) + order.shippingCost - order.discount)}',
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                                    softWrap: true,
                                                  ),
                                                  if (isSelected) ...[
                                                    const SizedBox(height: 8),
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
                                                              label: const Text('Xem hóa đơn'),
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
                                                                    _deleteOrder(order.orderId, order.status);
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

                                                          
                                                          if (order.status == OrderStatus.completed)
                                                          ElevatedButton.icon(
                                                            onPressed: _isLoading
                                                                ? null
                                                                : () {
                                                                    _deleteOrder(order.orderId, order.status);
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
                                                              label: const Text('Xem hóa đơn'),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.blue.shade600,
                                                                foregroundColor: Colors.white,
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                elevation: 3,
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                              ),
                                                            ),
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