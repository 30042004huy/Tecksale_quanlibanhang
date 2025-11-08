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
import 'package:google_fonts/google_fonts.dart'; // Thêm dòng này
import 'dart:convert'; // Đảm bảo import này có trong file splash.dart
import 'dart:async';
import 'package:intl/date_symbol_data_local.dart'; // ✨ THÊM DÒNG NÀY
import 'package:flutter/foundation.dart' show kIsWeb; // ✨ THÊM DÒNG NÀY

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
  bool _dataLoaded = false;
  final PrinterService _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
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
      _runInitialization(); // ✨ 1. Gọi hàm khởi tạo thật
    });
  }
    void _updateLoadingText(String text) {
    if (mounted) {
      setState(() {
        _loadingText = text;
      });
    }
  }

  // Hàm mới để bắt đầu quá trình tải mượt mà
  void _startSmoothLoading() {
    // Bắt đầu tải dữ liệu thực tế trong nền
    _initializeApp().then((_) {
      // Đánh dấu là dữ liệu đã tải xong
      _dataLoaded = true;
    });

    // Tạo một Timer để cập nhật thanh progress một cách mượt mà
    const totalDuration = Duration(milliseconds: 1500); // Giả lập quá trình tải trong 3 giây
    const updateInterval = Duration(milliseconds: 50);
    int steps = (totalDuration.inMilliseconds / updateInterval.inMilliseconds).round();
    double stepValue = 1.0 / steps;
    int currentStep = 0;

    Timer.periodic(updateInterval, (timer) {
      if (mounted) {
        setState(() {
          _progress += stepValue;
          if (_progress >= 1.0) {
            _progress = 1.0;
          }
        });

        // Cập nhật text dựa trên tiến trình
        if (_progress < 0.3) {
           _updateLoadingText('Kiểm tra kết nối...');
        } else if (_progress < 0.6) {
           _updateLoadingText('Xác thực người dùng...');
        } else if (_progress < 0.9) {
           _updateLoadingText('Đang tải dữ liệu...');
        } else {
           _updateLoadingText('Hoàn tất!');
        }
        
        currentStep++;
        if (currentStep >= steps) {
          timer.cancel();
          // Khi timer chạy xong, kiểm tra xem dữ liệu đã tải xong chưa để chuyển trang
          _navigateToNextScreen();
        }
      } else {
        timer.cancel();
      }
    });
  }

// Hàm mới: Quản lý toàn bộ quá trình
Future<void> _runInitialization() async {
  // Reset trạng thái (quan trọng cho nút "Thử lại")
  _updateLoadingText('Kiểm tra kết nối...');
  _updateProgress(0.0, 'Kiểm tra kết nối...');
  
  try {
    // ✨ 2. Khởi tạo Locale
    await initializeDateFormatting('vi_VN', null);
    _updateProgress(0.2, 'Đang kết nối...');

    // ✨ 3. Kiểm tra mạng
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none || !await _hasInternet()) {
      // Nếu không có mạng, hiện popup và dừng lại
      _showNetworkErrorPopup(); 
      return; 
    }
    _updateProgress(0.4, 'Đã kết nối!');

    // ✨ 4. Kiểm tra xác thực
    _updateProgress(0.6, 'Xác thực người dùng...');
    final prefs = await SharedPreferences.getInstance();
    final authService = AuthService();
    final user = authService.getCurrentUser();
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    Widget nextScreen; // Dùng biến cục bộ, không dùng _initialScreen nữa

    if (user != null && rememberMe) {
      _updateProgress(0.8, 'Kiểm tra quyền truy cập...');
      final bool? isEnabledInDb = await authService.isUserEnabled(user.uid);
      
      if (isEnabledInDb == false) {
        await authService.signOut();
        nextScreen = DangNhapScreen();
      } else {
        // ✨ GỌI AppInitializer TẠI ĐÂY (nếu bạn chưa gọi ở main.dart)
        // await AppInitializer.preloadData(); 
        nextScreen = const TrangChuScreen();
      }
    } else {
      nextScreen = DangNhapScreen();
    }
    
    // ✨ 5. Hoàn tất và Điều hướng
    _updateProgress(1.0, 'Hoàn tất!');
    await Future.delayed(const Duration(milliseconds: 300)); // Chờ 0.3s để người dùng thấy chữ "Hoàn tất"

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    }

  } catch (e) {
    log('Splash: Lỗi khởi tạo ứng dụng: $e');
    // Nếu có lỗi bất kỳ, hiện popup
    _showNetworkErrorPopup();
  }
}


  // Hàm mới để điều hướng, đảm bảo cả timer và data loading đều xong
  Future<void> _navigateToNextScreen() async {
    // Đợi cho đến khi dữ liệu thực sự được tải xong
    while (!_dataLoaded) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Đảm bảo thanh progress đã đầy 100%
    if (mounted) {
        setState(() {
           _progress = 1.0;
           _loadingText = 'Hoàn tất!';
        });
    }
    
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _initialScreen),
      );
    }
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
                    _runInitialization();
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
  if (kIsWeb) {
    return true; // Nếu là Web, mặc định là có mạng
  }
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


// VỊ TRÍ: lib/screens/splash.dart -> trong class _SplashScreenState

Future<void> _initializeApp() async {
  try {
    // ✨ KHỞI TẠO LOCALE NGAY TẠI ĐÂY ✨
    // Tác vụ này rất nhanh và sẽ không ảnh hưởng đến hiệu suất.
    await initializeDateFormatting('vi_VN', null);

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none || !await _hasInternet()) {
      if (mounted) _showNetworkErrorPopup();
      return; 
    }

    final prefs = await SharedPreferences.getInstance();
    final authService = AuthService();
    final user = authService.getCurrentUser();
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    if (user != null && rememberMe) {
      final bool? isEnabledInDb = await authService.isUserEnabled(user.uid);
      if (isEnabledInDb == false) {
        await authService.signOut();
        _initialScreen = DangNhapScreen();
      } else {
_initialScreen = const TrangChuScreen();
      }
    } else {
      _initialScreen = DangNhapScreen();
    }
  } catch (e) {
    log('Splash: Lỗi khởi tạo ứng dụng: $e');
    _initialScreen = DangNhapScreen();
    if (mounted) {
      _showNetworkErrorPopup();
    }
  } finally {
      // ...
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
                      child: Text(
                        'TeckSale',
                        style: GoogleFonts.quicksand(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1976D2),
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
                          color: Color.fromARGB(255, 85, 85, 85),
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
                        '"Design TeckSale by Huy Lữ"',
                        style: TextStyle(fontSize: 15, color: Color.fromARGB(255, 137, 137, 137)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        ' ',
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