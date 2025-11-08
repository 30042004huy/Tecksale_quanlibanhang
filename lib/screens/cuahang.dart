// VỊ TRÍ: lib/screens/cuahang.dart
// PHIÊN BẢN NÂNG CẤP UI/UX VÀ LOGIC ORDER
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'table_setup_screen.dart';

// Import các model và service cần thiết
import '../models/donhang_model.dart' as donhang_model;
import '../models/sanpham_model.dart';
import '../models/invoice_counter_model.dart'; // ✨ IMPORT MODEL MỚI
import '../services/custom_notification_service.dart';
import '../utils/format_currency.dart';
import '../services/vietqr_service.dart'; // Thêm import cho dịch vụ VietQR
// =================================================================
// 1. DATA MODELS (Không thay đổi)
// =================================================================
class Ban {
  final int id;
  String ten;
  String trangThai;
  DateTime? gioVao;
  int soKhach;
  String? orderId;
  double totalAmount;

  Ban({
    required this.id,
    required this.ten,
    this.trangThai = 'trong',
    this.gioVao,
    this.soKhach = 0,
    this.orderId,
    this.totalAmount = 0.0,
  });

  factory Ban.fromJson(Map<dynamic, dynamic> json, int id) {
    return Ban(
      id: id,
      ten: json['ten'] ?? 'Bàn ${id + 1}',
      trangThai: json['trang_thai'] ?? 'trong',
      soKhach: json['so_khach'] ?? 0,
      gioVao: json['gio_vao'] != null ? DateTime.tryParse(json['gio_vao']) : null,
      orderId: json['orderId'],
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ten': ten,
      'trang_thai': trangThai,
      'so_khach': soKhach,
      'gio_vao': gioVao?.toIso8601String(),
      'orderId': orderId,
      'totalAmount': totalAmount,
    };
  }
}

// =================================================================
// 2. MAIN SCREEN WIDGET
// =================================================================
class CuaHangScreen extends StatefulWidget {
  const CuaHangScreen({super.key});
  @override
  State<CuaHangScreen> createState() => _CuaHangScreenState();
}

class _CuaHangScreenState extends State<CuaHangScreen> {
  // --- STATE & DATABASE REFERENCES ---
  final dbRef = FirebaseDatabase.instance.ref();
  final uid = FirebaseAuth.instance.currentUser?.uid;
  late DatabaseReference _cuaHangRef;
  
  List<Ban> _banList = [];
  List<SanPham> _fullProductList = [];
  bool _isLoading = true;

  // --- LIFECYCLE ---
  @override
  void initState() {
    super.initState();
    if (uid != null) {
      _cuaHangRef = dbRef.child('nguoidung/$uid/cuahang');
      _initializeData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  // --- DATA INITIALIZATION ---
  Future<void> _initializeData() async {
    await _loadFullProductList();
    _listenToTableChanges();
  }

// VỊ TRÍ: lib/screens/cuahang.dart
// THAY THẾ TOÀN BỘ HÀM NÀY:

Future<void> _loadFullProductList() async {
  if (uid == null) return;
  
  try {
    final snapshot = await dbRef.child('nguoidung/$uid/sanpham').get();
    
    if (snapshot.exists && snapshot.value is Map) {
      final data = snapshot.value as Map;
      final List<SanPham> products = []; // Tạo list rỗng

      // ✨ SỬ DỤNG VÒNG LẶP FOR AN TOÀN THAY VÌ .map()
      for (var entry in data.entries) {
        try {
          // 1. Chỉ thử parse nếu e.value thực sự là một Map
          if (entry.value is Map) {
            final sp = SanPham.fromMap(entry.value, entry.key);
            products.add(sp);
          } else {
            // 2. Nếu e.value không phải Map (bị rác), in ra cảnh báo
            print('Cảnh báo: Bỏ qua sản phẩm lỗi/rác tại key: ${entry.key}');
          }
        } catch (e) {
          // 3. Nếu parse lỗi (thiếu trường, sai kiểu...), cũng bỏ qua
          print('Lỗi parse sản phẩm tại key ${entry.key}: $e');
        }
      }

      // Sắp xếp sau khi đã lọc
      products.sort((a, b) => a.tenSP.toLowerCase().compareTo(b.tenSP.toLowerCase()));
      
      if (mounted) {
        setState(() => _fullProductList = products);
      }
    }
  } catch (e) {
    // Thêm catch lỗi cho cả hàm
    if(mounted) {
      CustomNotificationService.show(context, message: 'Lỗi nghiêm trọng khi tải sản phẩm: $e', textColor: Colors.red);
    }
  }
}
  void _listenToTableChanges() {
    _cuaHangRef.child('ban_list').onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data != null && data is List) {
        final List<Ban> loadedBans = [];
        for (int i = 0; i < data.length; i++) {
          if (data[i] != null) {
            loadedBans.add(Ban.fromJson(data[i], i));
          }
        }
        setState(() {
          _banList = loadedBans;
          _isLoading = false;
        });
      } else {
        setState(() {
          _banList = [];
          _isLoading = false;
        });
      }
    });
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text('Sơ đồ bàn', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSetupDialog,
            tooltip: 'Cài đặt bàn',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDashboard(),
                Expanded(
                  child: _banList.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 155.0,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: _banList.length,
                          itemBuilder: (context, index) => FadeInUp(
                            delay: Duration(milliseconds: 50 * index),
                            child: _buildTableCard(_banList[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
  
  // =================================================================
  // 3. UI WIDGETS (Không thay đổi nhiều)
  // =================================================================
  
  Widget _buildDashboard() {
    int soBanCoKhach = _banList.where((b) => b.trangThai == 'co_khach').length;
    int soBanTrong = _banList.length - soBanCoKhach;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDashboardItem('Tổng', _banList.length.toString(), Colors.blue.shade700),
            _buildDashboardItem('Có khách', soBanCoKhach.toString(), Colors.orange.shade700),
            _buildDashboardItem('Trống', soBanTrong.toString(), Colors.green.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardItem(String title, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
      ],
    );
  }

  Widget _buildTableCard(Ban ban) {
    final (Color, Color, IconData) config = switch (ban.trangThai) {
      'co_khach' => (Colors.orange.shade600, Colors.orange.shade50, Icons.people_alt_rounded),
      _ => (Colors.green.shade600, Colors.green.shade50, Icons.chair_rounded)
    };
    final (borderColor, backgroundColor, iconData) = config;

    return GestureDetector(
      onTap: () => _handleTableTap(ban),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [BoxShadow(color: borderColor.withOpacity(0.1), blurRadius: 8, spreadRadius: 2)]
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: 32, color: borderColor),
              const SizedBox(height: 8),
              Text(ban.ten, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const Spacer(),
              if (ban.trangThai == 'co_khach')
                Column(
                  children: [
                    Text(
                      'Giờ vào:  ${ban.gioVao != null ? DateFormat('HH:mm').format(ban.gioVao!) : ''}',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    if (ban.totalAmount > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          FormatCurrency.format(ban.totalAmount),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Chưa có bàn nào được thiết lập.', style: TextStyle(fontSize: 16, color: Colors.black54)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showSetupDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thiết lập ngay'),
          ),
        ],
      ),
    );
  }
  
  // =================================================================
  // 4. CORE LOGIC & EVENT HANDLERS (LOGIC TẠO ORDER GIỮ NGUYÊN)
  // =================================================================
  
  void _handleTableTap(Ban ban) {
    _showOccupiedTableOptions(ban);
  }

  // ✨ HÀM LẤY SỐ HÓA ĐƠN TIẾP THEO
  Future<String> _getNextInvoiceNumber() async {
    final dateKey = DateFormat('yyyyMMdd').format(DateTime.now());
    final ref = dbRef.child('nguoidung/$uid/invoice_counters/$dateKey');
    
    final result = await ref.runTransaction((Object? post) {
      if (post == null) {
        // Nếu chưa có counter cho ngày hôm nay, tạo mới
        return Transaction.success({'counter': 1});
      }
      final data = Map<String, dynamic>.from(post as Map);
      data['counter'] = (data['counter'] ?? 0) + 1;
      return Transaction.success(data);
    });

    final newCounter = result.snapshot.child('counter').value as int;
    // Format: HD-20231026-0001
    return '$dateKey-${newCounter.toString().padLeft(4, '0')}';
  }

  Future<String?> _createOrderForTableIfNeeded(Ban ban) async {
    if (uid == null) return null;
    if (ban.orderId != null) return ban.orderId;

    // ✨ SỬ DỤNG HÀM LẤY SỐ HÓA ĐƠN MỚI
    final newOrderId = await _getNextInvoiceNumber();

    final newOrderRef = dbRef.child('nguoidung/$uid/donhang/saved/$newOrderId');
    final newOrder = donhang_model.OrderData(
      orderId: newOrderId,
      orderDate: DateTime.now(),
      customerName: ban.ten,
      customerPhone: '',
      items: [],
      shippingCost: 0,
      discount: 0,
      notes: 'Đơn hàng cho ${ban.ten}',
      status: donhang_model.OrderStatus.saved, // Trạng thái ban đầu
      employeeId: uid!,
    );
    await newOrderRef.set(newOrder.toMap());

    await _cuaHangRef.child('ban_list/${ban.id}').update({
      'trang_thai': 'co_khach',
      'so_khach': 1, // Mặc định 1 khách
      'gio_vao': DateTime.now().toIso8601String(),
      'orderId': newOrder.orderId,
    });

    return newOrder.orderId;
  }

// VỊ TRÍ: lib/screens/cuahang.dart
// THAY THẾ TOÀN BỘ HÀM _showAddItemDialog BẰNG PHIÊN BẢN NÀY

Future<void> _showAddItemDialog(Ban ban) async {
  final orderId = await _createOrderForTableIfNeeded(ban);
  
  // ✨ BƯỚC 1: Lấy context của màn hình chính (CuaHangScreen) một cách an toàn.
  // Context này sẽ luôn tồn tại ngay cả khi dialog đã đóng.
  final mainScreenContext = context;
  if (!mounted) return;

  final orderRef = dbRef.child('nguoidung/$uid/donhang/saved/$orderId');
  final snapshot = await orderRef.get();

  if (!snapshot.exists) {
    CustomNotificationService.show(mainScreenContext, message: 'Không tìm thấy đơn hàng.');
    return;
  }

  final currentOrder = donhang_model.OrderData.fromMap(snapshot.value as Map);
  final Map<String, donhang_model.OrderItem> tempItems = {
    for (var item in currentOrder.items) item.productId: item
  };

  showDialog(
    context: mainScreenContext,
    barrierDismissible: false,
    builder: (dialogContext) => 
      _AddItemDialogContent(
        fullProductList: _fullProductList,
        initialItems: tempItems,
        onSave: (updatedItems) async {
          // ✨ BƯỚC 2: THAY ĐỔI THỨ TỰ LOGIC
          
          final updatedOrder = currentOrder.copyWith(
            items: updatedItems.values.toList(),
          );

          // 1. Lưu vào Firebase
          await orderRef.set(updatedOrder.toMap());

          // 2. Cập nhật tổng tiền lên bàn
          await _cuaHangRef
              .child('ban_list/${ban.id}')
              .update({'totalAmount': updatedOrder.totalAmount});

          // 3. Hiển thị thông báo THÀNH CÔNG dùng context của màn hình chính
          // Context này luôn hợp lệ vì nó không bị pop/phá hủy.
          CustomNotificationService.show(mainScreenContext, message: 'Đã cập nhật đơn hàng!');

          // 4. Đóng dialog SAU CÙNG, khi mọi việc đã hoàn tất
          if (Navigator.canPop(dialogContext)) {
             Navigator.of(dialogContext).pop();
          }
        },
      ),
  );
}

  // --- 5.2: DIALOG "XEM MÓN ĐÃ CHỌN" NÂNG CẤP ---
  void _showOrderDetailsDialog(Ban ban) {
    if (uid == null || ban.orderId == null) {
      CustomNotificationService.show(context, message: 'Bàn này chưa có đơn hàng.');
      return;
    }

    final orderRef = dbRef.child('nguoidung/$uid/donhang/saved/${ban.orderId}');

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<DatabaseEvent>(
        future: orderRef.once(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return AlertDialog(
              title: const Text('Lỗi'),
              content: const Text('Không tìm thấy thông tin đơn hàng.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
            );
          }

          final orderData = donhang_model.OrderData.fromMap(snapshot.data!.snapshot.value as Map);
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            title: Text('Chi tiết đơn hàng: ${ban.ten}', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              // ✨ SỬ DỤNG SCROLLBAR VÀ DANH SÁCH ĐẸP HƠN
              child: orderData.items.isEmpty
                  ? const Center(heightFactor: 3, child: Text('Chưa có món nào được thêm.'))
                  : Scrollbar(
                      thumbVisibility: true,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: orderData.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final item = orderData.items[index];
                          return ListTile(
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text('Đơn giá: ${FormatCurrency.format(item.unitPrice)}',style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // ✨ SỐ LƯỢNG Ở TRÊN
                                Text(
                                  'x${item.quantity}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                                const SizedBox(height: 4),
                                // ✨ TỔNG TIỀN Ở DƯỚI
                                Text(
                                  FormatCurrency.format(item.unitPrice * item.quantity),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            actions: [
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng cộng:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    FormatCurrency.format(orderData.totalAmount),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 5.3: BOTTOM SHEET LỰA CHỌN (Không thay đổi) ---
 // VỊ TRÍ: lib/screens/cuahang.dart

void _showOccupiedTableOptions(Ban ban) {
  final bool isTableEmpty = ban.trangThai == 'trong';

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        children: [
          ListTile(
            title: Text(ban.ten, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            subtitle: Builder(
              builder: (context) {
                if (isTableEmpty) {
                  return const Text('Bàn trống');
                }
                final gioVaoText = ban.gioVao != null
                    ? ' • Vào lúc ${DateFormat('HH:mm').format(ban.gioVao!)}'
                    : '';
                return Text('${ban.soKhach} khách${gioVaoText}');
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_shopping_cart_rounded, color: Colors.blue),
            title: const Text('Thêm món'),
            onTap: () {
              Navigator.pop(context);
              _showAddItemDialog(ban);
            },
          ),
          ListTile(
            leading: Icon(Icons.receipt_long_rounded, color: isTableEmpty ? Colors.grey : Colors.purple),
            title: Text('Xem món đã chọn', style: TextStyle(color: isTableEmpty ? Colors.grey : Colors.black)),
            onTap: isTableEmpty ? null : () {
              Navigator.pop(context);
              _showOrderDetailsDialog(ban);
            },
          ),
          ListTile(
            leading: Icon(Icons.payment_rounded, color: isTableEmpty ? Colors.grey : Colors.green),
            title: Text('Thanh toán', style: TextStyle(color: isTableEmpty ? Colors.grey : Colors.black)),
            onTap: isTableEmpty ? null : () {
               Navigator.pop(context);
               _showPaymentOptionsDialog(ban);
            },
          ),
          // ✨ THÊM LỰA CHỌN "HỦY ĐƠN HÀNG" MỚI
          ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: isTableEmpty ? Colors.grey : Colors.red),
            title: Text('Hủy đơn hàng', style: TextStyle(color: isTableEmpty ? Colors.grey : Colors.red)),
            onTap: isTableEmpty ? null : () {
               Navigator.pop(context);
               // Sẽ tạo hàm này ở bước tiếp theo
               _showCancelOrderConfirmationDialog(ban);
            },
          ),
        ],
      ),
    ),
  );
}

// VỊ TRÍ: lib/screens/cuahang.dart
// THAY THẾ TOÀN BỘ HÀM CŨ BẰNG PHIÊN BẢN NÀY

Future<void> _showCancelOrderConfirmationDialog(Ban ban) async {
  if (uid == null || ban.orderId == null) {
    CustomNotificationService.show(context, message: 'Bàn này không có đơn hàng để hủy.');
    return;
  }

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      // ✨ THIẾT KẾ LẠI DIALOG THEO PHONG CÁCH HIỆN ĐẠI
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Bỏ title mặc định để tùy chỉnh layout bên trong content
        title: null,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✨ 1. Thêm Icon cảnh báo nổi bật
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 50),
            const SizedBox(height: 16),
            // ✨ 2. Tiêu đề rõ ràng, font chữ đẹp hơn
            Text(
              'Xác nhận hủy đơn',
              style: GoogleFonts.quicksand(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // ✨ 3. Nội dung chi tiết, làm nổi bật tên bàn
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: Colors.black54, fontSize: 15, height: 1.5, fontFamily: 'Quicksand'),
                children: <TextSpan>[
                  const TextSpan(text: 'Bạn có chắc chắn muốn hủy toàn bộ đơn hàng của bàn '),
                  TextSpan(
                    text: ban.ten,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const TextSpan(text: ' không? Thao tác này không thể hoàn tác.'),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          // ✨ 4. Thiết kế lại các nút hành động
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Không'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: Colors.red.withOpacity(0.4)
                  ),
                  child: const Text('Đồng ý hủy'),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    
                    final orderRef = dbRef.child('nguoidung/$uid/donhang/saved/${ban.orderId}');
                    try {
                      await orderRef.remove();
                      await _cuaHangRef.child('ban_list/${ban.id}').update({
                        'trang_thai': 'trong',
                        'so_khach': 0,
                        'gio_vao': null,
                        'orderId': null,
                        'totalAmount': 0.0,
                      });

                      if (mounted) {
                        CustomNotificationService.show(
                          context,
                          message: 'Đã hủy đơn hàng của ${ban.ten}.',
                          textColor: Colors.orange.shade800,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        CustomNotificationService.show(
                          context,
                          message: 'Lỗi khi hủy đơn hàng. Vui lòng thử lại.',
                          textColor: Colors.red,
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
  // --- 5.4: DIALOG THANH TOÁN (Không thay đổi) ---

void _showPaymentOptionsDialog(Ban ban) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (context) => _PaymentDialogContent(
      ban: ban,
      onConfirmPayment: () => _completeTable(ban),
    ),
  );
}
  
  // =================================================================
  // 6. FIREBASE DATA UPDATE FUNCTIONS
  // =================================================================
  
 Future<void> _completeTable(Ban ban) async {
  if (uid == null || ban.orderId == null) return;
  
  final savedOrderRef = dbRef.child('nguoidung/$uid/donhang/saved/${ban.orderId}');
  final orderSnapshot = await savedOrderRef.get();

  if (orderSnapshot.exists) {
      // ✨ LOGIC ĐÚNG: Chuyển đơn hàng từ 'saved' sang 'completed'
      final orderData = orderSnapshot.value as Map;
      
      // Cập nhật trạng thái đơn hàng thành 'completed'
      orderData['status'] = donhang_model.OrderStatus.completed.name; 

      final completedOrderRef = dbRef.child('nguoidung/$uid/donhang/completed/${ban.orderId}');
      
      // 1. Sao chép đơn hàng qua mục 'completed'
      await completedOrderRef.set(orderData);
      // 2. Xóa đơn hàng khỏi mục 'saved'
      await savedOrderRef.remove();
  }

  // Reset bàn về trạng thái 'trống'
  await _cuaHangRef.child('ban_list/${ban.id}').update({
      'trang_thai': 'trong',
      'so_khach': 0,
      'gio_vao': null,
      'orderId': null,
      'totalAmount': 0.0,
  });

  CustomNotificationService.show(context, message: '${ban.ten} đã hoàn tất!', textColor: Colors.green);
}
  

void _showSetupDialog() {
  if (uid == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => TableSetupScreen(
        uid: uid!,
        currentTables: _banList,
      ),
    ),
  );
}
}

// =================================================================
// ✨ 7. WIDGET RIÊNG CHO DIALOG "CHỌN MÓN" ĐỂ QUẢN LÝ STATE (PHIÊN BẢN SỬA LỖI UI CUỐI CÙNG)
// =================================================================
class _AddItemDialogContent extends StatefulWidget {
  final List<SanPham> fullProductList;
  final Map<String, donhang_model.OrderItem> initialItems;
  final Function(Map<String, donhang_model.OrderItem> updatedItems) onSave;

  const _AddItemDialogContent({
    required this.fullProductList,
    required this.initialItems,
    required this.onSave,
  });

  @override
  State<_AddItemDialogContent> createState() => _AddItemDialogContentState();
}

class _AddItemDialogContentState extends State<_AddItemDialogContent> {
  late Map<String, donhang_model.OrderItem> _currentItems;
  List<SanPham> _filteredProducts = [];
  double _totalAmount = 0;

  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentItems = Map.from(widget.initialItems);
    _filteredProducts = widget.fullProductList;
    _calculateTotal();

    _searchController.addListener(() {
      _filterProducts();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterProducts() {
    final searchTerm = _searchController.text;
    setState(() {
      if (searchTerm.isEmpty) {
        _filteredProducts = widget.fullProductList;
      } else {
        _filteredProducts = widget.fullProductList.where((p) => 
          p.tenSP.toLowerCase().contains(searchTerm.toLowerCase()) || 
          p.maSP.toLowerCase().contains(searchTerm.toLowerCase())
        ).toList();
      }
    });
  }

  void _calculateTotal() {
    double total = 0;
    _currentItems.forEach((key, item) {
      total += item.unitPrice * item.quantity;
    });
    setState(() => _totalAmount = total);
  }

  void _updateItemQuantity(SanPham product, int change) {
    setState(() {
      final existingItem = _currentItems[product.id];
      if (existingItem != null) {
        final newQuantity = existingItem.quantity + change;
        if (newQuantity > 0) {
          _currentItems[product.id] = existingItem.copyWith(quantity: newQuantity);
        } else {
          _currentItems.remove(product.id);
        }
      } else if (change > 0) {
        _currentItems[product.id] = donhang_model.OrderItem(
          productId: product.id,
          name: product.tenSP,
          quantity: 1,
          unit: product.donVi,
          unitPrice: product.donGia,
        );
      }
      _calculateTotal();
    });
  }
  
  AppBar _buildAppBar(BuildContext context) {
    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
            _searchFocusNode.unfocus();
          },
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tìm kiếm sản phẩm...',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _searchController.clear(),
          ),
        ],
      );
    } else {
      return AppBar(
        elevation: 1,
        shadowColor: Colors.grey.shade200,
        leading: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            setState(() => _isSearching = true);
            _searchFocusNode.requestFocus();
          },
        ),
        title: Text('Chọn món', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(context),
          body: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final selectedItem = _currentItems[product.id];
                return _buildProductListItem(product, selectedItem);
              },
            ),
          ),
          // ✨ [FIX] Sửa lại toàn bộ BottomAppBar để khắc phục lỗi.
          bottomNavigationBar: BottomAppBar(
            elevation: 1,
            child: Container(
              // ✨ [FIX 2] Thay đổi padding để "đẩy" nội dung lên cao hơn.
              padding: const EdgeInsets.fromLTRB(1, 1, 1, 2),
              child: Row(
                children: [
                  // ✨ [FIX 1] Bọc Column trong Flexible để ưu tiên không gian, tránh bị nút "Xong" chèn ép.
                  Flexible(
                    fit: FlexFit.tight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tổng cộng', style: TextStyle(color: Color.fromARGB(255, 144, 144, 144), fontSize: 14)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            FormatCurrency.format(_totalAmount),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 0),
                  ElevatedButton(
                    onPressed: () => widget.onSave(_currentItems),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
                      elevation: 1,
                      shadowColor: Colors.blue.withOpacity(0.5),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.blue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                      child: Container(
                        // ✨ [FIX 2] Tăng padding dọc để nút "Xong" cao hơn và trông lớn hơn.
                        // ✨ [FIX 2] Giảm padding ngang một chút để dành không gian cho tổng tiền.
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        child: const Text(
                          'Xong',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductListItem(SanPham product, donhang_model.OrderItem? selectedItem) {
    final int quantity = selectedItem?.quantity ?? 0;
    final bool isSelected = quantity > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: InkWell(
        onTap: () => _updateItemQuantity(product, 1),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue.shade200 : Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.tenSP, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(FormatCurrency.format(product.donGia), style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              _buildQuantitySelector(product, quantity),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(SanPham product, int quantity) {
    if (quantity == 0) return const SizedBox.shrink();

    return Row(
      children: [
        const SizedBox(width: 16),
        Text(
          quantity.toString(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(width: 8),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent),
          onPressed: () => _updateItemQuantity(product, -1),
        ),
      ],
    );
  }
}
// VỊ TRÍ: lib/screens/cuahang.dart
// ✨ THAY THẾ TOÀN BỘ CLASS NÀY Ở CUỐI FILE

class _PaymentDialogContent extends StatefulWidget {
  final Ban ban;
  final Future<void> Function() onConfirmPayment;

  const _PaymentDialogContent({
    required this.ban,
    required this.onConfirmPayment,
  });

  @override
  State<_PaymentDialogContent> createState() => _PaymentDialogContentState();
}

class _PaymentDialogContentState extends State<_PaymentDialogContent> {
  // State vẫn giữ nguyên để quản lý việc hiển thị QR
  bool _isShowingQr = false;
  bool _isQrLoading = false;
  Uint8List? _qrImageData;
  String? _qrError;

  // Hàm tạo QR vẫn giữ nguyên
  Future<void> _generateQr() async {
    setState(() {
      _isQrLoading = true;
      _qrError = null;
    });

    final qrData = await VietQRService.generateQrCode(amount: widget.ban.totalAmount);

    if (mounted) {
      setState(() {
        if (qrData != null) {
          _qrImageData = qrData;
        } else {
          _qrError = "Không thể tạo mã QR. Vui lòng kiểm tra lại thông tin ngân hàng trong cài đặt.";
          // Tự động ẩn phần QR nếu có lỗi
          _isShowingQr = false;
        }
        _isQrLoading = false;
      });
    }
  }

  // ✨ CẤU TRÚC LẠI HOÀN TOÀN HÀM BUILD
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
          ),
          // ✨ Dùng Column để xây dựng một layout thống nhất
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- PHẦN THÔNG TIN LUÔN HIỂN THỊ ---
              Text('Thanh toán cho ${widget.ban.ten}', style: GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(FormatCurrency.format(widget.ban.totalAmount), style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.green.shade800)),
              if (_qrError != null) ...[
                const SizedBox(height: 16),
                Text(_qrError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),

              // --- PHẦN CÁC LỰA CHỌN ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Bấm nút này sẽ bật/tắt phần hiển thị QR
                    setState(() {
                      _isShowingQr = !_isShowingQr;
                      // Nếu bật và chưa có ảnh, thì mới gọi API
                      if (_isShowingQr && _qrImageData == null) {
                        _generateQr();
                      }
                    });
                  },
                  icon: Icon(_isShowingQr ? Icons.keyboard_arrow_up_rounded : Icons.qr_code_2_rounded),
                  label: const Text('Thanh toán QR'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),

              // --- ✨ PHẦN HIỂN THỊ QR (CHỈ HIỆN KHI _isShowingQr LÀ TRUE) ---
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isShowingQr ? _buildQrView() : const SizedBox.shrink(),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Logic in hóa đơn
                  },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('In hóa đơn'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const Divider(height: 32),

              // --- ✨ PHẦN NÚT XÁC NHẬN VÀ HỦY (LUÔN HIỂN THỊ) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                   onPressed: () => Navigator.pop(context),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 241, 241, 241),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                    ),
                    child: const Text('Hủy', style: TextStyle(fontSize: 14, color: Color.fromARGB(255, 26, 129, 255))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Đóng dialog
                      widget.onConfirmPayment(); // Gọi hàm hoàn tất bàn
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                    ),
                    child: const Text('Xác nhận', style: TextStyle(fontSize: 14, color: Color.fromARGB(255, 255, 255, 255))),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // ✨ HÀM NÀY GIỜ CHỈ TRẢ VỀ PHẦN NỘI DUNG QR
  Widget _buildQrView() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: SizedBox(
        width: 270,
        height: 270,
        child: _isQrLoading
            ? const Center(child: CircularProgressIndicator())
            : _qrImageData != null
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, spreadRadius: 2)]
                    ),
                    child: Image.memory(_qrImageData!, fit: BoxFit.contain),
                  )
                : const Center(child: Text("Lỗi tạo mã QR", style: TextStyle(color: Colors.red))),
      ),
    );
  }
}