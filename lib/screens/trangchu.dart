import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:developer';
import 'dart:async';

import '../utils/format_currency.dart';
import 'baocao.dart';
import 'caidat.dart';
import 'donhang.dart';
import 'khachhang.dart';
import 'sanpham.dart';
import 'taodon.dart';
import 'taoqr.dart';
import 'thongbao.dart';
import 'hotro.dart';
import 'package:url_launcher/url_launcher.dart';


class TrangChuScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const TrangChuScreen({Key? key, this.initialData}) : super(key: key);

  @override
  State<TrangChuScreen> createState() => _TrangChuScreenState();
}

class _TrangChuScreenState extends State<TrangChuScreen> {
  final Color primaryColor = const Color.fromARGB(255, 31, 154, 255);
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String? _userId;

  String _tenCuaHang = "TeckSale";
  DateTime _selectedDate = DateTime.now();
  int _orderCount = 0;
  double _totalRevenue = 0.0;
  int _draftOrderCount = 0;
  int _savedOrderCount = 0;
  double _revenuePercentageChange = 0.0;
  double _orderPercentageChange = 0.0;

  StreamSubscription<DatabaseEvent>? _completedOrdersSubscription;
  StreamSubscription<DatabaseEvent>? _savedOrdersSubscription;
  StreamSubscription<DatabaseEvent>? _draftOrdersSubscription;
  StreamSubscription<DatabaseEvent>? _storeInfoSubscription;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    if (widget.initialData != null) {
      setState(() {
        _tenCuaHang = widget.initialData!['tenCuaHang'] ?? "TeckSale";
        _orderCount = widget.initialData!['orderCount'] ?? 0;
        _totalRevenue = widget.initialData!['totalRevenue'] ?? 0.0;
        _draftOrderCount = widget.initialData!['draftOrderCount'] ?? 0;
        _savedOrderCount = widget.initialData!['savedOrderCount'] ?? 0;
        _revenuePercentageChange = widget.initialData!['revenuePercentageChange'] ?? 0.0;
        _orderPercentageChange = widget.initialData!['orderPercentageChange'] ?? 0.0;
        _selectedDate = widget.initialData!['selectedDate'] ?? DateTime.now();
      });
    }
    _loadStoreName();
    _startListeningToOrders();
  }

  @override
  void dispose() {
    _completedOrdersSubscription?.cancel();
    _savedOrdersSubscription?.cancel();
    _draftOrdersSubscription?.cancel();
    _storeInfoSubscription?.cancel();
    super.dispose();
  }
    final List<Map<String, dynamic>> _featureItems = [
      {
        'icon': Icons.note_add,
        'label': "Tạo đơn",
        'color': const Color.fromARGB(255, 209, 162, 20),
        'page': TaoDonScreen()
      },
      {
        'icon': Icons.inventory_2,
        'label': "Đơn hàng",
        'color': const Color.fromARGB(255, 200, 104, 8),
        'page': const DonHangScreen()
      },
      {
        'icon': Icons.all_inbox,
        'label': "Sản phẩm",
        'color': const Color.fromARGB(255, 6, 119, 189),
        'page': SanPhamScreen()
      },
      {
        'icon': Icons.people,
        'label': "Khách hàng",
        'color': const Color.fromARGB(255, 64, 127, 15),
        'page': KhachHangScreen()
      },
      {
        'icon': Icons.analytics,
        'label': "Báo cáo",
        'color': Colors.indigo,
        'page': const BaoCaoScreen()
      },
      {
        'icon': Icons.qr_code,
        'label': "Tạo QR",
        'color': const Color.fromARGB(255, 125, 45, 45),
        'page': TaoQRScreen()
      },
    ];
  Future<void> _loadStoreName() async {
    if (_userId == null) return;

    try {
      final snapshot = await _dbRef.child('nguoidung/$_userId/thongtincuahang').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _tenCuaHang = data['tenCuaHang']?.toString() ?? "TeckSale";
        });
      }
    } catch (e) {
      log("Lỗi khi tải tên cửa hàng: $e");
      setState(() {
        _tenCuaHang = "TeckSale";
      });
    }

    // Listen for real-time updates to store name
    _storeInfoSubscription = _dbRef.child('nguoidung/$_userId/thongtincuahang').onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _tenCuaHang = data['tenCuaHang']?.toString() ?? "TeckSale";
        });
      } else {
        setState(() {
          _tenCuaHang = "TeckSale";
        });
      }
    }, onError: (error) {
      log("Lỗi khi lắng nghe tên cửa hàng: $error");
    });
  }

  void _startListeningToOrders() {
    if (_userId == null) return;

    _completedOrdersSubscription = _dbRef.child('nguoidung/$_userId/donhang/completed').onValue.listen((event) {
      _updateQuickReportData(_selectedDate);
    });

    _savedOrdersSubscription = _dbRef.child('nguoidung/$_userId/donhang/saved').onValue.listen((event) {
      _updateQuickReportData(_selectedDate);
    });

    _draftOrdersSubscription = _dbRef.child('nguoidung/$_userId/donhang/draft').onValue.listen((event) {
      _updateQuickReportData(_selectedDate);
    });
  }

  Future<void> _updateQuickReportData(DateTime date) async {
    if (_userId == null) return;

    int totalOrderCount = 0;
    double totalItemsSum = 0.0;
    double discountSum = 0.0;
    int previousOrderCount = 0;
    double previousTotalItemsSum = 0.0;
    double previousDiscountSum = 0.0;
    int draftOrderCount = 0;
    int savedOrderCount = 0;

    for (var status in ['completed', 'saved']) {
      try {
        final snapshot = await _dbRef.child('nguoidung/$_userId/donhang/$status').get();
        if (snapshot.exists) {
          final Map<dynamic, dynamic> ordersMap = snapshot.value as Map<dynamic, dynamic>;
          ordersMap.forEach((key, value) {
            try {
              final orderDateEpoch = (value['orderDate'] as num?)?.toInt();
              if (orderDateEpoch != null) {
                final orderDate = DateTime.fromMillisecondsSinceEpoch(orderDateEpoch);
                if (orderDate.year == date.year && orderDate.month == date.month && orderDate.day == date.day) {
                  totalOrderCount++;
                  final items = value['items'] as List<dynamic>?;
                  double orderItemsSum = 0.0;
                  if (items != null) {
                    for (var item in items) {
                      final itemMap = Map<String, dynamic>.from(item);
                      final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
                      final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
                      orderItemsSum += unitPrice * quantity;
                    }
                  }
                  final discount = (value['discount'] as num?)?.toDouble() ?? 0.0;
                  totalItemsSum += orderItemsSum;
                  discountSum += discount;
                }
              }
            } catch (e) {
              log("Lỗi khi phân tích đơn hàng ($status): $e");
            }
          });
        }
      } catch (e) {
        log("Lỗi khi tải dữ liệu đơn hàng ($status): $e");
      }
    }

    final previousDate = date.subtract(const Duration(days: 1));
    for (var status in ['completed', 'saved']) {
      try {
        final snapshot = await _dbRef.child('nguoidung/$_userId/donhang/$status').get();
        if (snapshot.exists) {
          final Map<dynamic, dynamic> ordersMap = snapshot.value as Map<dynamic, dynamic>;
          ordersMap.forEach((key, value) {
            try {
              final orderDateEpoch = (value['orderDate'] as num?)?.toInt();
              if (orderDateEpoch != null) {
                final orderDate = DateTime.fromMillisecondsSinceEpoch(orderDateEpoch);
                if (orderDate.year == previousDate.year && orderDate.month == previousDate.month && orderDate.day == previousDate.day) {
                  previousOrderCount++;
                  final items = value['items'] as List<dynamic>?;
                  double orderItemsSum = 0.0;
                  if (items != null) {
                    for (var item in items) {
                      final itemMap = Map<String, dynamic>.from(item);
                      final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
                      final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
                      orderItemsSum += unitPrice * quantity;
                    }
                  }
                  final discount = (value['discount'] as num?)?.toDouble() ?? 0.0;
                  previousTotalItemsSum += orderItemsSum;
                  previousDiscountSum += discount;
                }
              }
            } catch (e) {
              log("Lỗi khi phân tích đơn hàng trước đó ($status): $e");
            }
          });
        }
      } catch (e) {
        log("Lỗi khi tải dữ liệu đơn hàng trước đó ($status): $e");
      }
    }

    try {
      final draftSnapshot = await _dbRef.child('nguoidung/$_userId/donhang/draft').get();
      if (mounted) {
        final ordersMap = draftSnapshot.value as Map<dynamic, dynamic>?;
        draftOrderCount = ordersMap?.length ?? 0;
      }
    } catch (e) {
      log("Lỗi khi tải dữ liệu đơn hàng nháp: $e");
    }

    try {
      final savedSnapshot = await _dbRef.child('nguoidung/$_userId/donhang/saved').get();
      if (mounted) {
        final ordersMap = savedSnapshot.value as Map<dynamic, dynamic>?;
        savedOrderCount = ordersMap?.length ?? 0;
      }
    } catch (e) {
      log("Lỗi khi tải dữ liệu đơn hàng đã lưu: $e");
    }

    if (mounted) {
      setState(() {
        _orderCount = totalOrderCount;
        _totalRevenue = totalItemsSum - discountSum;
        final previousRevenue = previousTotalItemsSum - previousDiscountSum;
        if (previousRevenue != 0) {
          _revenuePercentageChange = ((_totalRevenue - previousRevenue) / previousRevenue) * 100;
        } else if (_totalRevenue != 0) {
          _revenuePercentageChange = 100.0;
        } else {
          _revenuePercentageChange = 0.0;
        }
        if (previousOrderCount != 0) {
          _orderPercentageChange = ((totalOrderCount - previousOrderCount) / previousOrderCount) * 100;
        } else if (totalOrderCount != 0) {
          _orderPercentageChange = 100.0;
        } else {
          _orderPercentageChange = 0.0;
        }
        _draftOrderCount = draftOrderCount;
        _savedOrderCount = savedOrderCount;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateQuickReportData(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, const Color.fromARGB(255, 10, 102, 194)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logoapp.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      const SizedBox(width: 9),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Quản Lý Bán Hàng",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5,
                            child: Text(
                              _tenCuaHang,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return Row(
                        mainAxisSize: MainAxisSize.min, // Giúp Row chỉ chiếm không gian cần thiết
                        children: [
                          _buildHeaderButton(
                            icon: Icons.notifications_none,
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThongBaoScreen())),
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderButton(
                            icon: Icons.settings_outlined,
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CaiDatScreen())),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Report Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 164, 211, 255),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Báo cáo nhanh",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              GestureDetector(
                                onTap: _selectDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        (_selectedDate.year == DateTime.now().year &&
                                                _selectedDate.month == DateTime.now().month &&
                                                _selectedDate.day == DateTime.now().day)
                                            ? 'Hôm Nay'
                                            : DateFormat('dd/MM/yyyy').format(_selectedDate),
                                        style: const TextStyle(color: Color.fromARGB(137, 0, 0, 0), fontSize: 14),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_drop_down, size: 20, color: Color.fromARGB(135, 89, 89, 89)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickBox(
                                  icon: Icons.assignment_turned_in,
                                  label: "Đơn hàng",
                                  value: _orderCount.toString(),
                                  iconColor: const Color.fromARGB(255, 207, 101, 2),
                                  isRevenue: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildQuickBox(
                                  icon: Icons.payments,
                                  label: "Doanh thu",
                                  value: FormatCurrency.format(_totalRevenue, decimalDigits: 0),
                                  iconColor: const Color.fromARGB(255, 3, 157, 21),
                                  isRevenue: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Features Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Chức năng",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _featureItems.length,
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 120, // Điều chỉnh kích thước này để phù hợp với ý muốn của bạn
                              childAspectRatio: 1,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                            itemBuilder: (context, index) {
                              final item = _featureItems[index];
                              return _buildFeatureItem(context, item['icon'], item['label'], item['color'], item['page']);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Order Status Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Trạng thái đơn hàng",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          _buildOrderStatusCard(
                            title: "Đơn chưa hoàn tất",
                            count: _savedOrderCount.toString(),
                            icon: Icons.pending_actions,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          _buildOrderStatusCard(
                            title: "Đơn nháp",
                            count: _draftOrderCount.toString(),
                            icon: Icons.edit_note,
                            color: const Color.fromARGB(255, 110, 122, 130),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Support Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Liên hệ hỗ trợ",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSupportItem(
                                context,
                                "assets/images/logoAI.png",
                                "ChatAI",
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => HoTroScreen())),
                              ),
                              _buildSupportItem(
                                context,
                                "assets/images/logomess.png",
                                "Messenger",
                                () => launchUrl(Uri.parse("http://m.me/107005565374824"), mode: LaunchMode.externalApplication),
                              ),
                              _buildSupportItem(
                                context,
                                "assets/images/logozalo.png",
                                "Zalo",
                                () => showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                                    contentPadding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset("assets/images/qrzalo.jpg", width: 220),
                                          const SizedBox(height: 16),
                                          const Text(
                                            "Quét mã QR bằng ứng dụng Zalo và lấy thông tin để được hỗ trợ",
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      Center(
                                        child: TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Đóng", style: TextStyle(fontSize: 14)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickBox({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required bool isRevenue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 242, 249, 255),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 42, 42, 42).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                (isRevenue ? _revenuePercentageChange : _orderPercentageChange) >= 0
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                color: (isRevenue ? _revenuePercentageChange : _orderPercentageChange) >= 0 ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${(isRevenue ? _revenuePercentageChange : _orderPercentageChange).abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  color: (isRevenue ? _revenuePercentageChange : _orderPercentageChange) >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String label, Color iconColor, Widget page) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 18, 32, 45).withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportItem(BuildContext context, String imagePath, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(imagePath, width: 40, height: 40),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                "$count đơn",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
    Widget _buildHeaderButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        splashColor: Colors.white.withOpacity(0.3),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}