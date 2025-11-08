// VỊ TRÍ: lib/screens/nhapkho.dart
// PHIÊN BẢN CẢI TIẾN: UI HIỆN ĐẠI + SỬA LỖI DATA AN TOÀN

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import '../services/custom_notification_service.dart';
import '../models/sanpham_model.dart';

// =================================================================
// MAIN WIDGET: NhapKhoScreen
// =================================================================
class NhapKhoScreen extends StatefulWidget {
  const NhapKhoScreen({super.key});

  @override
  State<NhapKhoScreen> createState() => _NhapKhoScreenState();
}

class _NhapKhoScreenState extends State<NhapKhoScreen> {
  // --- STATE MANAGEMENT ---
  final dbRef = FirebaseDatabase.instance.ref();
  User? user;
  StreamSubscription<DatabaseEvent>? _sanPhamSubscription;

  List<SanPham> _dsSanPhamGoc = [];
  List<SanPham> _dsSanPhamDaLoc = [];
  Map<String, int> _phieuNhapKho = {};

  bool _isLoading = true;
  String _searchText = '';

  // --- LIFECYCLE & DATA HANDLING ---
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _sanPhamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    await _listenToProductChanges();
  }

  Future<void> _listenToProductChanges() async {
    final sanPhamRef = dbRef.child('nguoidung/${user!.uid}/sanpham');
    _sanPhamSubscription = sanPhamRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map) {
        // --- ✨ SỬA LỖI QUAN TRỌNG TẠI ĐÂY ---
        // Sử dụng vòng lặp an toàn để tránh crash do dữ liệu rác
        final List<SanPham> list = [];
        for (var entry in data.entries) {
          try {
            if (entry.value is Map) {
              list.add(SanPham.fromMap(entry.value, entry.key));
            } else {
              print(
                  'Cảnh báo (nhapkho): Bỏ qua sản phẩm lỗi/rác tại key: ${entry.key}');
            }
          } catch (e) {
            print('Lỗi parse sản phẩm (nhapkho) tại key ${entry.key}: $e');
          }
        }
        // --- KẾT THÚC SỬA LỖI ---

        list.sort((a, b) => a.tenSP.toLowerCase().compareTo(b.tenSP.toLowerCase()));
        setState(() {
          _dsSanPhamGoc = list;
          _filterProducts();
        });
      }
      setState(() => _isLoading = false);
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomNotificationService.show(context,
            message: 'Lỗi tải dữ liệu sản phẩm.', textColor: Colors.red);
      }
    });
  }

  void _filterProducts() {
    setState(() {
      if (_searchText.isEmpty) {
        _dsSanPhamDaLoc = List.from(_dsSanPhamGoc);
      } else {
        final searchLower = _searchText.toLowerCase();
        _dsSanPhamDaLoc = _dsSanPhamGoc
            .where((sp) =>
                sp.tenSP.toLowerCase().contains(searchLower) ||
                sp.maSP.toLowerCase().contains(searchLower))
            .toList();
      }
    });
  }

  // --- BATCH IMPORT (CART) LOGIC ---
  void _addToCart(SanPham sp, int soLuong) {
    setState(() {
      if (soLuong > 0) {
        _phieuNhapKho[sp.id] = soLuong;
      } else {
        _phieuNhapKho.remove(sp.id);
      }
    });
  }

  Future<void> _confirmNhapKho() async {
    if (user == null || _phieuNhapKho.isEmpty) return;
    final productRef = dbRef.child('nguoidung/${user!.uid}/sanpham');
    List<Future<void>> updateTasks = [];
    _phieuNhapKho.forEach((productId, quantity) {
      final task = productRef.child(productId).runTransaction((Object? post) {
        if (post == null) return Transaction.abort();
        Map<String, dynamic> _post = Map<String, dynamic>.from(post as Map);
        final currentTonKho = _post['tonKho'] as int? ?? 0;
        _post['tonKho'] = currentTonKho + quantity;
        return Transaction.success(_post);
      });
      updateTasks.add(task);
    });
    try {
      await Future.wait(updateTasks);
      CustomNotificationService.show(context,
          message: 'Nhập kho thành công!', textColor: Colors.green);
      setState(() => _phieuNhapKho.clear());
    } catch (e) {
      CustomNotificationService.show(context,
          message: 'Lỗi khi nhập kho.', textColor: Colors.red);
    }
  }

  // --- BARCODE SCANNING ---
  Future<void> _scanBarcode() async {
    var status = await Permission.camera.request();
    if (!status.isGranted && mounted) {
      CustomNotificationService.show(context,
          message: 'Vui lòng cấp quyền camera.', textColor: Colors.red);
      return;
    }
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 320,
          height: 320,
          child: _ScannerDialogContent(
            onProductFound: (SanPham product) {
              Navigator.of(context).pop();
              _showNhapKhoDialog(product);
            },
            dsSanPham: _dsSanPhamGoc,
          ),
        ),
      ),
    );
  }

  // --- UI DIALOGS ---
  Future<void> _showNhapKhoDialog(SanPham sp) async {
    final quantityController = TextEditingController();
    quantityController.text = (_phieuNhapKho[sp.id] ?? 1).toString();

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sp.tenSP,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.quicksand(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Tồn kho hiện tại: ${sp.tonKho ?? 0}',
                          style: GoogleFonts.roboto(color: Colors.black54)),
                      const SizedBox(height: 24),
                      _buildHybridQuantityStepper(
                        controller: quantityController,
                        onChanged: (newQuantity) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                              child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Hủy'))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final int quantity =
                                    int.tryParse(quantityController.text) ?? 0;
                                Navigator.pop(context);
                                _addToCart(sp, quantity);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Xác nhận'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =================================================================
  // UI BUILDER METHODS (ĐÃ THIẾT KẾ LẠI)
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      body: _buildBodyContent(),
      bottomNavigationBar: _buildConfirmButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('Nhập Kho',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
      centerTitle: true,
      foregroundColor: Colors.white,
      backgroundColor: Colors.blue.shade700,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
          onPressed: _scanBarcode,
          tooltip: 'Quét Barcode',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildProductList()),
      ],
    );
  }

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          onChanged: (value) {
            _searchText = value;
            _filterProducts();
          },
          decoration: InputDecoration(
            hintText: 'Tìm theo tên hoặc mã sản phẩm...',
            hintStyle: GoogleFonts.roboto(color: Colors.grey.shade600),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
      );

  Widget _buildProductList() {
    if (_dsSanPhamDaLoc.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchText.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.inventory_2_outlined,
              size: 100,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _searchText.isNotEmpty
                  ? 'Không tìm thấy sản phẩm'
                  : 'Chưa có sản phẩm nào',
              style: GoogleFonts.roboto(fontSize: 18, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _dsSanPhamDaLoc.length,
      itemBuilder: (context, index) {
        final sp = _dsSanPhamDaLoc[index];
        final isInCart = _phieuNhapKho.containsKey(sp.id);
        // ✨ ĐÃ XÓA FADEINUP (GÂY LAG)
        return _buildProductCard(sp, isInCart);
      },
    );
  }

  // --- ✨ THẺ SẢN PHẨM (ĐÃ THIẾT KẾ LẠI) ---
  Widget _buildProductCard(SanPham sp, bool isInCart) {
    return InkWell(
      onTap: () => _showNhapKhoDialog(sp),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isInCart ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInCart ? Colors.blue.shade300 : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isInCart ? Colors.blue.withOpacity(0.1) : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Icon
            Icon(
              isInCart ? Icons.check_circle : Icons.inventory_2_outlined,
              color: isInCart ? Colors.blue.shade700 : Colors.grey.shade400,
              size: 32,
            ),
            const SizedBox(width: 16),
            // Tên & Mã
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sp.tenSP,
                      style: GoogleFonts.quicksand(
                          fontSize: 16.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Mã: ${sp.maSP} - Tồn: ${sp.tonKho ?? 0}',
                    style: GoogleFonts.roboto(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Chip số lượng
            if (_phieuNhapKho[sp.id] != null)
              Chip(
                label: Text('+${_phieuNhapKho[sp.id]}',
                    style: GoogleFonts.roboto(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800)),
                backgroundColor: Colors.blue.shade100,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              )
            else
              const Icon(Icons.add_circle_outline,
                  color: Colors.grey, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    if (_phieuNhapKho.isEmpty) return const SizedBox.shrink();
    int totalItems = _phieuNhapKho.length;
    int totalQuantity = _phieuNhapKho.values.fold(0, (sum, item) => sum + item);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _confirmNhapKho,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: Colors.green.withOpacity(0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text('$totalQuantity (+$totalItems loại)',
                    style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  Text('Xác nhận nhập kho',
                      style: GoogleFonts.quicksand(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// WIDGETS: Reusable Components
// =================================================================

// ✨ BỘ ĐIỀU KHIỂN SỐ LƯỢNG MỚI - CHO PHÉP NHẬP BẰNG TAY
Widget _buildHybridQuantityStepper(
    {required TextEditingController controller,
    required ValueChanged<int> onChanged}) {
  void updateQuantity(int delta) {
    int currentValue = int.tryParse(controller.text) ?? 0;
    int newValue = currentValue + delta;
    if (newValue >= 0) {
      controller.text = newValue.toString();
      onChanged(newValue);
    }
  }

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        icon: const Icon(Icons.remove_circle_outline_rounded),
        onPressed: () => updateQuantity(-1),
        iconSize: 32,
        color: Colors.red.shade400,
      ),
      Expanded(
        child: TextField(
          controller: controller,
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.bold),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) => onChanged(int.tryParse(value) ?? 0),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline_rounded),
        onPressed: () => updateQuantity(1),
        iconSize: 32,
        color: Colors.green.shade600,
      ),
    ],
  );
}

// =================================================================
// WIDGETS: Barcode Scanner (Giữ nguyên, đã tối ưu)
// =================================================================
class _ScannerDialogContent extends StatefulWidget {
  final List<SanPham> dsSanPham;
  final Function(SanPham) onProductFound;
  const _ScannerDialogContent(
      {required this.dsSanPham, required this.onProductFound});

  @override
  State<_ScannerDialogContent> createState() => _ScannerDialogContentState();
}

class _ScannerDialogContentState extends State<_ScannerDialogContent>
    with TickerProviderStateMixin {
  final MobileScannerController _scannerController =
      MobileScannerController(autoStart: true);
  late AnimationController _animationController;
  bool _canScan = true;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (!_canScan || capture.barcodes.isEmpty) return;
    setState(() => _canScan = false);
    final barcodeValue = capture.barcodes.first.rawValue;
    if (barcodeValue != null) {
      try {
        final product =
            widget.dsSanPham.firstWhere((sp) => sp.maSP == barcodeValue);
        widget.onProductFound(product);
      } catch (e) {
        CustomNotificationService.show(context,
            message: 'Không tìm thấy sản phẩm này.', textColor: Colors.orange);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _canScan = true);
        });
      }
    } else {
      setState(() => _canScan = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetection,
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => CustomPaint(
              size: Size.infinite,
              painter:
                  AnimatedScannerOverlayPainter(animation: _animationController),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.cancel, color: Colors.white, size: 32),
              tooltip: 'Đóng',
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedScannerOverlayPainter extends CustomPainter {
  final Animation<double> animation;
  AnimatedScannerOverlayPainter({required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final cornerLength = 20.0;
    final strokeWidth = 4.0;
    final rect = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * 0.6,
        height: size.width * 0.6);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        rect.topLeft, rect.topLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(
        rect.topLeft, rect.topLeft + Offset(0, cornerLength), paint);
    canvas.drawLine(
        rect.topRight, rect.topRight - Offset(cornerLength, 0), paint);
    canvas.drawLine(
        rect.topRight, rect.topRight + Offset(0, cornerLength), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft - Offset(0, cornerLength), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight - Offset(cornerLength, 0), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight - Offset(0, cornerLength), paint);
    final scanY = rect.top + rect.height * animation.value;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0),
          Colors.white,
          Colors.white.withOpacity(0)
        ],
        stops: const [0.1, 0.5, 0.9],
      ).createShader(Rect.fromLTWH(rect.left, scanY - 2, rect.width, 4));
    canvas.drawRect(Rect.fromLTWH(rect.left, scanY - 2, rect.width, 4), scanPaint);
  }

  @override
  bool shouldRepaint(covariant AnimatedScannerOverlayPainter oldDelegate) {
    return animation.value != oldDelegate.animation.value;
  }
}