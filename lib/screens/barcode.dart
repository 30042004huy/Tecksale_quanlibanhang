import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sanpham_model.dart' as sanpham;
import '../utils/format_currency.dart';
import 'taodon.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../services/custom_notification_service.dart';


class BarcodeScannerScreen extends StatefulWidget {
  final List<ProductWithQuantity> initialProducts;

  const BarcodeScannerScreen({
    Key? key,
    required this.initialProducts,
  }) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> with WidgetsBindingObserver {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
  late MobileScannerController controller;
  late List<ProductWithQuantity> scannedProducts;
  bool canScan = true;
  bool _isLoading = false;
  bool _isCameraReady = false;
  final AudioPlayer player = AudioPlayer();
  Timer? _debounceTimer; 
  String? scannedCode;
  final TextEditingController _codeController = TextEditingController();
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      formats: [BarcodeFormat.all],
      torchEnabled: false,
      facing: CameraFacing.back,
      autoStart: false,
    );
    scannedProducts = List<ProductWithQuantity>.from(widget.initialProducts);
    WidgetsBinding.instance.addObserver(this);
    controller.torchState.addListener(_updateTorchState);
    _initCameraAndPersistence();
  }

// Sửa lại hàm này
// VỊ TRÍ: lib/screens/barcode.dart -> bên trong class _BarcodeScannerScreenState

// Sửa lại hàm này
Future<void> _initCameraAndPersistence() async {
  try {
    FirebaseDatabase database = FirebaseDatabase.instance;
    database.setPersistenceEnabled(true);
    database.setPersistenceCacheSizeBytes(10000000);

    // ✨ BẮT ĐẦU THÊM MÃ TẠI ĐÂY ✨
    // Yêu cầu Firebase chủ động đồng bộ và giữ cho dữ liệu sản phẩm luôn được cập nhật.
    // Thao tác này sẽ "làm nóng" bộ nhớ đệm (cache) cho đúng dữ liệu chúng ta cần.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      dbRef.child('nguoidung/${user.uid}/sanpham').keepSynced(true);
    }
    // ✨ KẾT THÚC THÊM MÃ ✨

  } catch (e) {
    debugPrint('Error setting Firebase persistence or sync: $e');
  }

  await _requestCameraPermission();
  await _loadCameraPreference(); // Tải và cài đặt hướng camera

  if (mounted) {
    // Chỉ khởi động camera sau khi mọi thứ đã sẵn sàng
    await controller.start(); 
    setState(() {
      _isCameraReady = true;
    });
  }
}

// Sửa lại hàm này
Future<void> _loadCameraPreference() async {
  final prefs = await SharedPreferences.getInstance();
  final savedFacing = prefs.getString('camera_facing') ?? 'back';
  final newFacing = savedFacing == 'back' ? CameraFacing.back : CameraFacing.front;
  
  if (controller.facing != newFacing) {
    await controller.switchCamera();
    // Không cần lưu lại vì đây là lúc tải lên
  }
  // Xoá dòng "await controller.start();" ở đây nếu có
}

  void _updateTorchState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quyền truy cập camera bị từ chối.')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      controller.stop();
    } else if (state == AppLifecycleState.resumed && _isCameraReady) {
      controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.torchState.removeListener(_updateTorchState);
    controller.dispose();
    player.dispose();
    _codeController.dispose();
    // Hủy Timer
    _debounceTimer?.cancel(); 
    super.dispose();
  }

void _addOrUpdateProduct(sanpham.SanPham product) async {
  // Dừng âm thanh cũ (nếu có) và phát lại từ đầu để đảm bảo tiếng "tít" rõ ràng
  try {
    await player.stop();
    await player.play(AssetSource('sound/barcode.mp3'));
  } catch (e) {
    debugPrint('Lỗi phát âm thanh: $e');
  }

  if (mounted) {
    setState(() {
      final existingIndex = scannedProducts.indexWhere((p) => p.product.id == product.id);
      if (existingIndex != -1) {
        // Nếu sản phẩm đã có, tăng số lượng và đưa lên đầu danh sách
        final productWithQuantity = scannedProducts.removeAt(existingIndex);
        productWithQuantity.quantity += 1;
        scannedProducts.insert(0, productWithQuantity);
      } else {
        // Nếu là sản phẩm mới, thêm vào đầu danh sách
        scannedProducts.insert(0, ProductWithQuantity(product: product, quantity: 1));
      }
      _codeController.clear();
    });
  }
}


  Future<void> _saveCameraPreference(CameraFacing facing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('camera_facing', facing == CameraFacing.back ? 'back' : 'front');
  }

  Future<void> _showProductSelectionDialog(String code, List<sanpham.SanPham> products) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Chọn sản phẩm', style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                title: Text(product.tenSP, style: GoogleFonts.roboto(fontSize: 16)),
                subtitle: Text(FormatCurrency.format(product.donGia), style: GoogleFonts.roboto(fontSize: 14, color: Colors.green)),
                onTap: () {
                  Navigator.pop(context);
                  _addOrUpdateProduct(product);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Clear on cancel if desired, but keeping as is to allow retry
            },
            child: Text('Hủy', style: GoogleFonts.roboto(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

// VỊ TRÍ: lib/screens/barcode.dart -> trong class _BarcodeScannerScreenState

Future<void> _processCode(String code) async {
  // Nếu camera không sẵn sàng quét, hoặc đang xử lý một mã khác, thoát ngay
  if (!canScan || !mounted) return;

  try {
    // 1. KHÓA NGAY LẬP TỨC: Ngăn chặn mọi lần quét tiếp theo
    setState(() {
      canScan = false;
      _isLoading = true; // Hiển thị vòng xoay loading
      _codeController.text = code; // Cập nhật mã lên UI
    });

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final snapshot = await dbRef.child('nguoidung/$userId/sanpham').orderByChild('maSP').equalTo(code).get();

    if (snapshot.exists) {
      final productData = snapshot.value as Map<dynamic, dynamic>;
      final products = productData.entries.map((e) => sanpham.SanPham.fromMap(e.value, e.key)).toList();

      if (products.length == 1) {
        _addOrUpdateProduct(products[0]);
      } else if (products.length > 1) {
        // Vẫn giữ logic chọn sản phẩm nếu có nhiều mã trùng nhau
        await _showProductSelectionDialog(code, products);
      }
    } else {
      // 2. SỬ DỤNG THÔNG BÁO MỚI: Rõ ràng và không chồng chéo
      _showProductNotFoundNotification(code);
    }
  } catch (e) {
    // Xử lý lỗi kết nối mạng bằng thông báo tùy chỉnh
    if (mounted) {
      CustomNotificationService.show(
        context,
        message: 'Lỗi: Không thể xử lý. Vui lòng kiểm tra kết nối mạng.',
        textColor: Colors.red,
      );
    }
  } finally {
    // 3. LUÔN LUÔN THỰC THI SAU CÙNG:
    // Bất kể thành công, thất bại hay có lỗi, khối này sẽ luôn được chạy.
    if (mounted) {
      setState(() {
        _isLoading = false; // Tắt vòng xoay loading
      });

      // 4. ÁP DỤNG COOLDOWN 2 GIÂY:
      // Sau 2 giây, cho phép camera quét trở lại.
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            canScan = true;
          });
        }
      });
    }
  }
}

  void _addProductFromManualInput() {
    if (_codeController.text.isNotEmpty) {
      _processCode(_codeController.text);
    }
  }

void _showProductNotFoundNotification(String code) {
  if (mounted) {
    CustomNotificationService.show(
      context,
      message: 'Không tìm thấy sản phẩm có mã "$code"',
      textColor: Colors.orange.shade800, // Màu cam để cảnh báo
    );
  }
}

  double _calculateTotalCost() {
    return scannedProducts.fold(0.0, (sum, item) => sum + (item.product.donGia * item.quantity));
  }

  Widget _buildCartSection() {
    final totalQuantity = scannedProducts.fold(0, (sum, item) => sum + item.quantity);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Giỏ hàng',
              style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: scannedProducts.isEmpty
                ? Center(child: Text('Chưa có sản phẩm', style: GoogleFonts.roboto(color: Colors.grey, fontSize: 14)))
                : ListView.builder(
                    itemCount: scannedProducts.length,
                    itemBuilder: (context, index) {
                      final item = scannedProducts[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: const Icon(Icons.shopping_bag, color: Colors.blue, size: 24),
                          title: Text(
                            item.product.tenSP,
                            style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            FormatCurrency.format(item.product.donGia),
                            style: GoogleFonts.roboto(fontSize: 12, color: Colors.green),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    if (item.quantity > 1) {
                                      item.quantity--;
                                    } else {
                                      scannedProducts.removeAt(index);
                                    }
                                  });
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '${item.quantity}',
                                  style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green, size: 20),
                                onPressed: () => setState(() => item.quantity++),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: scannedProducts.isEmpty ? null : () => Navigator.pop(context, scannedProducts),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ).copyWith(
                  backgroundColor: MaterialStateProperty.resolveWith<Color>(
                    (states) => states.contains(MaterialState.disabled)
                      ? Colors.grey
                      : states.contains(MaterialState.pressed)
                        ? Colors.blue.shade700
                        : Colors.blue,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            const Icon(Icons.shopping_bag, color: Colors.white, size: 30),
                            if (scannedProducts.isNotEmpty)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Colors.red,
                                  child: Text(
                                    '$totalQuantity',
                                    style: GoogleFonts.roboto(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          FormatCurrency.format(_calculateTotalCost()),
                          style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Text(
                      'Tiếp tục',
                      style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final cameraSize = isLandscape ? screenHeight / 4 - 20 : (screenWidth - 20) / 4;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quét Barcode', style: GoogleFonts.roboto(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.blue,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
          actions: [
    IconButton(
      icon: Icon(controller.torchState.value == TorchState.on ? Icons.flash_on : Icons.flash_off),
      onPressed: () async {
        await controller.toggleTorch();
      },
    ),
    IconButton(
  icon: Icon(
    controller.facing == CameraFacing.back
        ? Icons.flip_camera_ios
        : Icons.flip_camera_ios_outlined,
  ),
  onPressed: () async {
    // 1. Chuyển camera trong controller
    await controller.switchCamera();
    
    // 2. Lấy giá trị camera mới sau khi chuyển
    final newFacing = controller.facing; 
    
    // 3. Lưu lại lựa chọn mới này
    await _saveCameraPreference(newFacing);
    
    // 4. Cập nhật UI để đổi icon
    if (mounted) {
      setState(() {});
    }
  },
),
  ],
),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: cameraSize,
                    height: cameraSize,
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade100, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: Stack(
                      children: [
                        if (_isCameraReady)
                          MobileScanner(
                            controller: controller,
// Thay thế onDetect cũ bằng code sau
onDetect: (capture) {
  // Chỉ xử lý nếu đang trong trạng thái cho phép quét (canScan)
  if (!canScan) return; 

  if (capture.barcodes.isNotEmpty) {
    final String? code = capture.barcodes.first.rawValue;
    
    if (code != null && code.isNotEmpty) {
      // 1. Dừng bất kỳ timer nào đang chạy để chỉ lấy mã cuối cùng được quét 
      _debounceTimer?.cancel();

      // 2. Cập nhật mã code và hiển thị lên TextField ngay lập tức (UI)
      if (mounted && _codeController.text != code) {
        setState(() {
          scannedCode = code;
          _codeController.text = code;
        });
      }

      // 3. Thiết lập timer 0.5 giây để tự động thêm sản phẩm (backend)
 _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 100), () { 
    if (mounted) {
      setState(() {
        canScan = true; // Mở khóa cho lần quét tiếp theo
      });
    
  
          // Bắt đầu quá trình thêm sản phẩm
          _processCode(code); 
        }
      });
    }
  }
},
                          )
                        else
                          const Center(child: CircularProgressIndicator(color: Colors.blue)),
                        Center(
                          child: Container(
                            width: cameraSize * 0.75,
                            height: cameraSize * 0.75,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green, width: 3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (_isLoading && _isCameraReady) const Center(child: CircularProgressIndicator(color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isLandscape ? screenWidth * 0.5 : 300),
                      child: TextField(
                        controller: _codeController,
                        decoration: InputDecoration(
                          labelText: scannedCode != null || _codeController.text.isNotEmpty ? null : 'Nhập hoặc quét mã code',
                          border: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addProductFromManualInput,
                          ),
                        ),
                        onSubmitted: (_) => _addProductFromManualInput(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _buildCartSection(),
          ],
        ),
      ),
    );
  }
}