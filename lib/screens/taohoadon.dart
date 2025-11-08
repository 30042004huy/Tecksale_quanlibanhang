// lib/screens/taohoadon.dart

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer';
import '../models/nhanvien_model.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/mauhoadon_model.dart';
import '../models/donhang_model.dart';
import '../services/saveimage_service.dart';
import '../widgets/uimauhoadon/uimauhoadona5.dart';
import '../widgets/uimauhoadon/uimauhoadon75mm.dart';
import '../services/printer_service.dart';

class TaoHoaDonScreen extends StatefulWidget {
  final OrderData orderData;
  final bool isModal; 

  const TaoHoaDonScreen({
    Key? key,
    required this.orderData,
    this.isModal = false, 
  }) : super(key: key);

  @override
  State<TaoHoaDonScreen> createState() => _TaoHoaDonScreenState();
}

class _TaoHoaDonScreenState extends State<TaoHoaDonScreen> {
  final GlobalKey _invoiceKey = GlobalKey();
  ShopInfo? _shopInfo;
  InvoiceSize _selectedInvoiceSize = InvoiceSize.A5;
  bool _isLoadingData = true;
  bool _isProcessing = false;
  List<NhanVien> _dsNhanVien = [];

  bool _showShopInfoInInvoice = true;
  bool _showCustomerInfoInInvoice = true;
  bool _showBankInfoInInvoice = true;
  bool _showQrCodeInInvoice = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final PrinterService _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    _loadAllRequiredData();
  }

  // ... (Tất cả các hàm logic như _loadAllRequiredData, _buildInvoiceData, _updateOrderStatus,
  // _updateInventory, _generateInvoiceImage, _saveInvoiceAsImage, _shareImage, _printInvoice,
  // _showProcessingDialog, _showSuccessDialog, _showErrorDialog, _showInfoDialog
  // _sanitizeFileName, _generateFileName VẪN GIỮ NGUYÊN NHƯ FILE CŨ)
  // ... (Vui lòng sao chép các hàm này từ phiên bản trước)

  Future<void> _loadAllRequiredData() async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        _showErrorDialog('Bạn cần đăng nhập để xem hóa đơn.');
      }
      return;
    }

    try {
      final results = await Future.wait([
        _dbRef.child('nguoidung/${user.uid}/nhanvien').get(),
        _dbRef.child('nguoidung/${user.uid}/thongtincuahang').get(),
        _dbRef.child('nguoidung/${user.uid}/mauhoadon').get(),
      ]);

      final nhanVienSnapshot = results[0];
      final shopSnapshot = results[1];
      final templateSnapshot = results[2];

      if (nhanVienSnapshot.exists) {
        final data = nhanVienSnapshot.value as Map<dynamic, dynamic>;
        _dsNhanVien = data.entries.map((e) => NhanVien.fromMap(e.key, e.value as Map)).toList();
      }

      ShopInfo shopInfo;
      if (shopSnapshot.exists && shopSnapshot.value != null) {
        final shopMap = Map<String, dynamic>.from(shopSnapshot.value as Map);
        shopInfo = ShopInfo(
          name: shopMap['tenCuaHang'] ?? 'Tên Cửa Hàng',
          phone: shopMap['soDienThoai'] ?? 'SĐT Cửa Hàng',
          address: shopMap['diaChi'] ?? 'Địa chỉ Cửa Hàng',
          bankName: shopMap['tenNganHang'] ?? '',
          accountNumber: shopMap['soTaiKhoan'] ?? '',
          accountName: shopMap['chuTaiKhoan'] ?? '',
          qrCodeUrl: '',
        );
      } else {
        shopInfo = ShopInfo(name: 'Cửa hàng của bạn', phone: '0000000000', address: 'Địa chỉ của bạn', bankName: '', accountNumber: '', accountName: '', qrCodeUrl: '');
      }
      _shopInfo = shopInfo;

      InvoiceSize selectedInvoiceSize = InvoiceSize.A5;
      bool showShop = true, showCustomer = true, showBank = true, showQr = true;

      if (templateSnapshot.exists && templateSnapshot.value != null) {
        final templateMap = Map<String, dynamic>.from(templateSnapshot.value as Map);
        
        final savedSizeString = templateMap['size'] as String?;
        if (savedSizeString != null) {
          selectedInvoiceSize = InvoiceSize.values.firstWhere(
            (e) => e.toString().split('.').last == savedSizeString,
            orElse: () => InvoiceSize.A5,
          );
        }

        showShop = templateMap['showShopInfo'] ?? true;
        showCustomer = templateMap['showCustomerInfo'] ?? true;
        showBank = templateMap['showBankInfo'] ?? true;
        showQr = templateMap['showQrCode'] ?? true;
      }

      if (mounted) {
        setState(() {
          _selectedInvoiceSize = selectedInvoiceSize;
          _showShopInfoInInvoice = showShop;
          _showCustomerInfoInInvoice = showCustomer;
          _showBankInfoInInvoice = showBank;
          _showQrCodeInInvoice = showQr;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      log('Lỗi khi tải dữ liệu hóa đơn: $e');
      if (mounted) {
        _showErrorDialog('Lỗi khi tải dữ liệu hóa đơn: $e');
        setState(() => _isLoadingData = false);
      }
    }
  }

  InvoiceData _buildInvoiceData() {
    List<InvoiceItem> invoiceItems = widget.orderData.items.map((orderItem) => InvoiceItem(
      name: orderItem.name,
      quantity: orderItem.quantity,
      unit: orderItem.unit,
      unitPrice: orderItem.unitPrice,
    )).toList();

    String? employeeNameToDisplay;
    if (widget.orderData.employeeId.isNotEmpty && _dsNhanVien.isNotEmpty) {
      final employee = _dsNhanVien.firstWhereOrNull((nv) => nv.id == widget.orderData.employeeId);
      employeeNameToDisplay = employee?.ten;
    }

    final shopInfo = _shopInfo ?? ShopInfo(name: 'Đang tải...', phone: '', address: '', bankName: '', accountNumber: '', accountName: '', qrCodeUrl: '');

    return InvoiceData(
      invoiceNumber: widget.orderData.orderId,
      shopInfo: shopInfo,
      customerInfo: CustomerInfo(
        name: widget.orderData.displayCustomerName, // ✨ SỬA
        phone: widget.orderData.displayCustomerPhone, // ✨ SỬA
      ),
      items: invoiceItems,
      shippingCost: widget.orderData.shippingCost,
      discount: widget.orderData.discount,
      notes: widget.orderData.notes,
      selectedSize: _selectedInvoiceSize,
      orderDate: widget.orderData.orderDate,
      employeeName: employeeNameToDisplay,
      showShopInfo: _showShopInfoInInvoice,
      showCustomerInfo: _showCustomerInfoInInvoice,
      showBankInfo: _showBankInfoInInvoice,
      showQrCode: _showQrCodeInInvoice,
    );
  }


  Future<void> _updateOrderStatus(OrderStatus status) async {
    final String statusMessage = (status == OrderStatus.saved) ? 'lưu' : 'cập nhật';
    _showProcessingDialog('Đang $statusMessage đơn hàng...');

    final user = _auth.currentUser!;
    
    if (status == OrderStatus.completed) {
      bool inventoryUpdated = await _updateInventory();
      if (!inventoryUpdated) {
        return; 
      }
    }

    final String oldStatusString = widget.orderData.status.toString().split('.').last;
    final String newStatusString = status.toString().split('.').last;
    
    await _dbRef.child('nguoidung/${user.uid}/donhang/$oldStatusString/${widget.orderData.orderId}').remove();
    
    final updatedOrder = widget.orderData.copyWith(status: status, savedAt: ServerValue.timestamp);

    await _dbRef.child('nguoidung/${user.uid}/donhang/$newStatusString/${widget.orderData.orderId}').set(updatedOrder.toMap());
    
    if (mounted) {
      if (Navigator.canPop(context)) Navigator.of(context).pop(); 
      _showSuccessDialog('Đã $statusMessage đơn hàng thành công!');
    }
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_').trim();
  }

  String _generateFileName() {
    final customerName = _sanitizeFileName(widget.orderData.customerName.isNotEmpty ? widget.orderData.customerName : 'KhachHang');
    final customerPhone = _sanitizeFileName(widget.orderData.customerPhone.isNotEmpty ? widget.orderData.customerPhone : 'Unknown');
    return 'hoadon_${customerName}_$customerPhone.png';
  }

  Future<bool> _updateInventory() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      for (var item in widget.orderData.items) {
        final productRef = _dbRef.child('nguoidung/${user.uid}/sanpham/${item.productId}');
        final snapshot = await productRef.get();
        if (snapshot.exists) {
          final productData = Map<String, dynamic>.from(snapshot.value as Map);
          final currentStock = (productData['tonKho'] as int?) ?? 0;
          if (currentStock < item.quantity) {
            if (mounted) _showErrorDialog('Sản phẩm "${item.name}" không đủ tồn kho.');
            return false;
          }
          await productRef.update({'tonKho': currentStock - item.quantity});
        }
      }
      return true;
    } catch (e) {
      if (mounted) _showErrorDialog('Không thể cập nhật tồn kho: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _generateInvoiceImage() async {
    try {
      final imageBytes = await SaveImageService.captureWidget(_invoiceKey);
      if (imageBytes == null) return {'isSuccess': false, 'error': 'Không thể tạo ảnh hóa đơn.'};
      final directory = await getTemporaryDirectory();
      final String fileName = _generateFileName();
      final String imagePath = '${directory.path}/$fileName';
      final File imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);
      return {'isSuccess': true, 'imagePath': imagePath};
    } catch (e) {
      log('Lỗi tạo ảnh cho chia sẻ: $e');
      return {'isSuccess': false, 'error': 'Lỗi khi tạo ảnh hóa đơn: $e'};
    }
  }

  Future<void> _saveInvoiceAsImage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _showProcessingDialog('Đang lưu ảnh hóa đơn...');

    try {
      final result = await SaveImageService.saveImageToGallery(_invoiceKey, fileName: _generateFileName());
      if(mounted) Navigator.of(context).pop();
      if (result['isSuccess'] == true) {
        if (mounted) _showSuccessDialog(result['message'] ?? 'Đã lưu ảnh hóa đơn!');
      } else {
        if (mounted) _showErrorDialog(result['error'] ?? 'Không thể lưu ảnh.');
      }
    } catch (e) {
      if(mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      if (mounted) _showErrorDialog('Lỗi khi lưu ảnh: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareImage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _showProcessingDialog('Đang chuẩn bị chia sẻ...');

    try {
      final result = await _generateInvoiceImage();
      if(mounted) Navigator.of(context).pop();
      if (!result['isSuccess']) {
        if (mounted) _showErrorDialog(result['error'] ?? 'Không thể tạo ảnh.');
        return;
      }
      await Share.shareXFiles([XFile(result['imagePath'])], text: 'Hóa đơn từ ${_shopInfo?.name ?? "Cửa hàng của bạn"}');
    } catch (e) {
      if(mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      if (mounted) _showErrorDialog('Lỗi khi chia sẻ hóa đơn: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _printInvoice() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _showProcessingDialog('Đang in hóa đơn...');

    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final imageBytes = await compute(SaveImageService.captureWidget, _invoiceKey);
      if (imageBytes == null) throw Exception('Không thể tạo ảnh hóa đơn để in.');
      await _printerService.printImage(imageBytes);
      if(mounted) Navigator.of(context).pop();
      if (mounted) _showSuccessDialog('Đã gửi lệnh in thành công!');
    } catch (e) {
      log('Lỗi khi in hóa đơn: $e');
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      if (mounted) _showErrorDialog('Lỗi khi in hóa đơn: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showProcessingDialog(String message) {
     if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text(message, style: GoogleFonts.roboto(fontSize: 16))),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    showDialog(context: context, builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 10), Text('Thành công', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold))]),
        content: Text(message, style: GoogleFonts.roboto()),
        actions: [ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(context: context, builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [const Icon(Icons.error, color: Colors.red), const SizedBox(width: 10), Text('Lỗi', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold))]),
        content: Text(message, style: GoogleFonts.roboto()),
        actions: [ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
  
  void _showInfoDialog(String title, String message) {
    if (!mounted) return;
    showDialog(context: context, builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Icon(Icons.info_outline, color: Colors.blue.shade700), const SizedBox(width: 10), Text(title, style: GoogleFonts.quicksand(fontWeight: FontWeight.bold))]),
        content: Text(message, style: GoogleFonts.roboto()),
        actions: [ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // 1. Định nghĩa widget chung để xây dựng nội dung hóa đơn
    Widget invoiceContentBuilder({ScrollController? scrollController}) {
      return Container(
        color: Colors.grey.shade200, 
        width: double.infinity,
        child: SingleChildScrollView(
          controller: scrollController, 
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade400,
                      blurRadius: 10,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: RepaintBoundary(
                key: _invoiceKey,
                child: _selectedInvoiceSize == InvoiceSize.A5
                    ? UIMauHoaDonA5(invoiceData: _buildInvoiceData())
                    : UIMauHoaDon75mm(invoiceData: _buildInvoiceData()),
              ),
            ),
          ),
        ),
      );
    }

    // 2. Nếu là modal, trả về giao diện DraggableScrollableSheet
    if (widget.isModal) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Tay nắm kéo
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Tiêu đề modal
                Text(
                  "Xem trước Hóa đơn",
                  style: GoogleFonts.quicksand(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                // Nội dung hóa đơn (có thể cuộn)
                Expanded(
                  child: _isLoadingData
                      ? const Center(child: CircularProgressIndicator())
                      : invoiceContentBuilder(scrollController: scrollController),
                ),
                
                // ✨✨✨ YÊU CẦU 1: THÊM NÚT HÀNH ĐỘNG CHO MODAL ✨✨✨
                if (!_isLoadingData) _buildModalActions(),
              ],
            ),
          );
        },
      );
    }

    // 3. Nếu không phải modal, trả về Scaffold đầy đủ (trang bình thường)
    return Scaffold(
      appBar: AppBar(
        title: Text('Xem & Quản lý Hóa đơn',
            style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : invoiceContentBuilder(),
      bottomNavigationBar: _isLoadingData ? null : _buildBottomActions(),
    );
  }

  // Widget cho các nút ở trang đầy đủ
  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
                icon: Icons.image_outlined,
                label: 'Lưu ảnh',
                color: Colors.green.shade700,
                onPressed: _isProcessing ? null : _saveInvoiceAsImage),
            _buildActionButton(
                icon: Icons.print_outlined,
                label: 'In ngay',
                color: Colors.red.shade700,
                onPressed: _isProcessing ? null : _printInvoice),
            _buildActionButton(
                icon: Icons.share_outlined,
                label: 'Chia sẻ',
                color: Colors.orange.shade700,
                onPressed: _isProcessing ? null : _shareImage),
          ],
        ),
      ),
    );
  }

  // ✨✨✨ WIDGET MỚI CHO CÁC NÚT Ở MODAL (THEO YÊU CẦU 1) ✨✨✨
  Widget _buildModalActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, // Nền trắng
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)), // Đường kẻ mỏng
      ),
      child: SafeArea(
        top: false, // Modal đã xử lý Safe Area
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Chỉ thêm 2 nút theo yêu cầu
            _buildActionButton(
                icon: Icons.image_outlined,
                label: 'Lưu ảnh',
                color: Colors.green.shade700,
                onPressed: _isProcessing ? null : _saveInvoiceAsImage),
            _buildActionButton(
                icon: Icons.share_outlined,
                label: 'Chia sẻ',
                color: Colors.orange.shade700,
                onPressed: _isProcessing ? null : _shareImage),
          ],
        ),
      ),
    );
  }


  // Widget con cho nút bấm (dùng chung)
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: onPressed == null ? Colors.grey : color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onPressed == null ? Colors.grey : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}