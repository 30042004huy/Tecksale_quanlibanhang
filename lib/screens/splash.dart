import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:tecksale_quanlybanhang/services/auth_service.dart';
import 'package:tecksale_quanlybanhang/services/printer_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dangnhap.dart';
import 'trangchu.dart';
import 'dart:developer';
import 'dart:io';

// Preload critical data before app starts
class AppInitializer {
  static String? _tenCuaHang;
  static bool _isPreloaded = false;

  static Future<void> preloadData() async {
    if (_isPreloaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (user != null) {
        _tenCuaHang = prefs.getString('tenCuaHang');
        if (_tenCuaHang == null) {
          final snapshot = await FirebaseDatabase.instance
              .ref()
              .child('nguoidung/${user.uid}/thongtincuahang/tenCuaHang')
              .get();
          _tenCuaHang = snapshot.exists ? snapshot.value as String? ?? "TeckSale" : "TeckSale";
          await prefs.setString('tenCuaHang', _tenCuaHang!);
        }
      }
      _isPreloaded = true;
    } catch (e) {
      log("Lỗi preload: $e");
      _tenCuaHang = "TeckSale";
    }
  }

  static String get tenCuaHang => _tenCuaHang ?? "TeckSale";
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late Widget _initialScreen;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  double _progress = 0.0;
  String _loadingText = 'Kiểm tra kết nối mạng...';
  bool _isInitialized = false;

  final PrinterService _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      _initializeApp(); // Thay thế bằng hàm khởi tạo chính
    });
  }

  void _updateProgress(double progress, String text) {
    if (mounted) {
      setState(() {
        _progress = progress.clamp(0.0, 1.0);
        _loadingText = text;
      });
    }
  }



  void _showNetworkErrorPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFE3F2FD)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 50, color: Color(0xFFE57373)),
                const SizedBox(height: 16),
                const Text(
                  'Không có kết nối mạng',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng kiểm tra kết nối mạng và thử lại.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Thay thế đoạn code trong hàm _showNetworkErrorPopup()
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Thay đổi tên hàm từ _checkNetworkAndInitialize() thành _initializeApp()
                    _initializeApp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: const Text(
                    'Thử lại',
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

Future<bool> _hasInternet() async {
  try {
    // Thử phân giải DNS: nếu không có internet sẽ ném SocketException
    final result = await InternetAddress.lookup('example.com');
    if (result.isEmpty || result.first.rawAddress.isEmpty) return false;

    // (Tuỳ chọn) thử mở socket nhanh để chắc chắn mạng thông
    final socket = await Socket.connect('clients3.google.com', 80,
        timeout: const Duration(seconds: 3));
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  } catch (_) {
    return false;
  }
}


  Future<void> _initializeApp() async {
  try {
 _updateProgress(0.2, 'Kiểm tra kết nối mạng...');

// 1) Có Wi-Fi/4G không?
final connectivityResult = await Connectivity().checkConnectivity();
final hasInterface = connectivityResult != ConnectivityResult.none;

// 2) Có internet thật không?
final hasInternet = await _hasInternet();

if (!hasInterface || !hasInternet) {
  _showNetworkErrorPopup();
  return; // Dừng mọi tải dữ liệu tiếp theo
}
    // (Thêm một độ trễ nhỏ để người dùng nhìn thấy)
    await Future.delayed(const Duration(milliseconds: 100)); 

      _updateProgress(0.3, 'Kiểm tra đăng nhập...');
      final prefs = await SharedPreferences.getInstance();
      final authService = AuthService();
      final user = authService.getCurrentUser();

      String tenCuaHang = AppInitializer.tenCuaHang;
      Map<String, dynamic> reportData = {
        'orderCount': 0,
        'totalRevenue': 0.0,
        'draftOrderCount': 0,
        'savedOrderCount': 0,
        'revenuePercentageChange': 0.0,
        'orderPercentageChange': 0.0,
      };
      DateTime selectedDate = DateTime.now();

      _updateProgress(0.4, 'Xác thực phiên làm việc...');
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      if (user != null && rememberMe) {
        _updateProgress(0.6, 'Kiểm tra trạng thái tài khoản...');
        try {
          final bool? isEnabledInDb = await authService.isUserEnabled(user.uid);
          if (isEnabledInDb != null && isEnabledInDb == false) {
            log('Splash: Tài khoản bị vô hiệu hóa trong DB. Buộc đăng xuất.');
            await authService.signOut();
            _initialScreen = DangNhapScreen();
          } else {
            _updateProgress(0.8, 'Tải dữ liệu...');
            final results = await Future.wait([
              _tryReconnectPrinter(user.uid),
              _loadQuickReportData(user.uid, selectedDate),
              AppInitializer.preloadData(),
            ]);

            reportData = results[1] as Map<String, dynamic>;
            tenCuaHang = AppInitializer.tenCuaHang;

            _initialScreen = TrangChuScreen(
              initialData: {
                'tenCuaHang': tenCuaHang,
                'orderCount': reportData['orderCount'],
                'totalRevenue': reportData['totalRevenue'],
                'draftOrderCount': reportData['draftOrderCount'],
                'savedOrderCount': reportData['savedOrderCount'],
                'revenuePercentageChange': reportData['revenuePercentageChange'],
                'orderPercentageChange': reportData['orderPercentageChange'],
                'selectedDate': selectedDate,
              },
            );
          }
        } on FirebaseAuthException catch (e) {
          log('Splash: Lỗi Firebase: ${e.message}');
          if (e.code == 'network-request-failed') {
            _updateProgress(0.0, 'Không có kết nối mạng...');
            _showNetworkErrorPopup();
            return;
          }
          await authService.signOut();
          _initialScreen = DangNhapScreen();
        } catch (e) {
          log('Splash: Lỗi không xác định: $e');
          _initialScreen = DangNhapScreen();
        }
      } else {
        log("Splash: Không có user hoặc chưa bật lưu thông tin. Đăng nhập.");
        _initialScreen = DangNhapScreen();
      }

      _updateProgress(0.95, 'Tối ưu kết nối...');
      await _preWarmFirebaseConnections(user?.uid);

      _updateProgress(1.0, 'Hoàn tất!');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => _initialScreen),
          );
        }
      }
    } catch (e) {
      log('Splash: Lỗi khởi tạo ứng dụng: $e');
      _updateProgress(0.0, 'Không có kết nối mạng...');
      _showNetworkErrorPopup();
    }
  }

  Future<void> _tryReconnectPrinter(String userId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('nguoidung/$userId/mayin');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final printerName = data['name'] as String?;
        if (printerName != null) {
          await _printerService.reconnectBluetoothPrinter(printerName);
        }
      }
    } catch (e) {
      log('Splash: Lỗi kết nối máy in: $e');
    }
  }

  Future<Map<String, dynamic>> _loadQuickReportData(String userId, DateTime date) async {
    int totalOrderCount = 0;
    double totalRevenue = 0.0;
    int draftOrderCount = 0;
    int savedOrderCount = 0;
    double revenuePercentageChange = 0.0;
    double orderPercentageChange = 0.0;

    final dbRef = FirebaseDatabase.instance.ref();
    final previousDate = date.subtract(const Duration(days: 1));

    try {
      final snapshot = await dbRef.child('nguoidung/$userId/donhang').get();
      final ordersMap = snapshot.exists ? snapshot.value as Map<dynamic, dynamic> : {};

      for (var status in ['completed', 'saved']) {
        final statusOrders = ordersMap[status] as Map<dynamic, dynamic>? ?? {};
        statusOrders.forEach((key, value) {
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
                totalRevenue += orderItemsSum - discount;
              }
            }
          } catch (e) {
            log("Lỗi khi phân tích đơn hàng ($status): $e");
          }
        });
      }

      draftOrderCount = (ordersMap['draft'] as Map<dynamic, dynamic>?)?.length ?? 0;
      savedOrderCount = (ordersMap['saved'] as Map<dynamic, dynamic>?)?.length ?? 0;

      int previousOrderCount = 0;
      double previousRevenue = 0.0;
      for (var status in ['completed', 'saved']) {
        final statusOrders = ordersMap[status] as Map<dynamic, dynamic>? ?? {};
        statusOrders.forEach((key, value) {
          try {
            final orderDateEpoch = (value['orderDate'] as num?)?.toInt();
            if (orderDateEpoch != null) {
              final orderDate = DateTime.fromMillisecondsSinceEpoch(orderDateEpoch);
              if (orderDate.year == previousDate.year &&
                  orderDate.month == previousDate.month &&
                  orderDate.day == previousDate.day) {
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
                previousRevenue += orderItemsSum - discount;
              }
            }
          } catch (e) {
            log("Lỗi khi phân tích đơn hàng trước đó ($status): $e");
          }
        });
      }

      if (previousRevenue != 0) {
        revenuePercentageChange = ((totalRevenue - previousRevenue) / previousRevenue) * 100;
      } else if (totalRevenue != 0) {
        revenuePercentageChange = 100.0;
      }

      if (previousOrderCount != 0) {
        orderPercentageChange = ((totalOrderCount - previousOrderCount) / previousOrderCount) * 100;
      } else if (totalOrderCount != 0) {
        orderPercentageChange = 100.0;
      }

    } catch (e) {
      log("Lỗi khi tải dữ liệu báo cáo: $e");
    }

    return {
      'orderCount': totalOrderCount,
      'totalRevenue': totalRevenue,
      'draftOrderCount': draftOrderCount,
      'savedOrderCount': savedOrderCount,
      'revenuePercentageChange': revenuePercentageChange,
      'orderPercentageChange': orderPercentageChange,
    };
  }

  Future<void> _preWarmFirebaseConnections(String? userId) async {
    if (userId == null) return;
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      await Future.wait([
        dbRef.child('nguoidung/$userId').get(),
        dbRef.child('nguoidung/$userId/sanpham').get(),
        dbRef.child('nguoidung/$userId/thongtincuahang').get(),
      ]);
    } catch (e) {
      log('Splash: Lỗi pre-warm Firebase: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _printerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE3F2FD), Color(0xFFF8F9FA)],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.asset(
                              'assets/images/logoapp.png',
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'TeckSale',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Quản lý bán hàng thông minh',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        _loadingText,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: 200,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const SpinKitThreeBounce(
                        color: Color(0xFF1976D2),
                        size: 24.0,
                      ),
                    ),
                    const SizedBox(height: 50),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Design TeckSale by Huy Lữ',
                        style: TextStyle(fontSize: 15, color: Color(0xFF999999)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        '"Version 1.1.1"',
                        style: TextStyle(fontSize: 10, color: Color(0xFF999999)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}