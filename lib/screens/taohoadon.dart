import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mauhoadon_model.dart';
import '../models/donhang_model.dart';
import '../models/thongtincuahang_model.dart';
import '../models/thongtinnganhang_model.dart';
import '../services/saveimage_service.dart';
import '../widgets/uimauhoadon/uimauhoadona5.dart';
import '../widgets/uimauhoadon/uimauhoadon75mm.dart';
import '../services/invoice_number_service.dart';

class TaoHoaDonScreen extends StatefulWidget {
  final OrderData orderData;

  const TaoHoaDonScreen({
    Key? key,
    required this.orderData,
  }) : super(key: key);

  @override
  State<TaoHoaDonScreen> createState() => _TaoHoaDonScreenState();
}

class _TaoHoaDonScreenState extends State<TaoHoaDonScreen> {
  final GlobalKey _invoiceKey = GlobalKey();
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _baseOffset = Offset.zero;
  ShopInfo? _shopInfo;
  BankInfo? _bankInfo;
  InvoiceSize _selectedInvoiceSize = InvoiceSize.A5;
  bool _isLoadingData = true;
  bool _isProcessing = false;
  String? _processingMessage;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Hàm chuẩn hóa tên file
  String _sanitizeFileName(String input) {
    return input
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Loại bỏ ký tự đặc biệt
        .replaceAll(RegExp(r'\s+'), '_') // Thay khoảng trắng bằng dấu gạch dưới
        .trim();
  }

  // Hàm tạo tên file theo cấu trúc hoadon.<tên khách hàng>.<số điện thoại khách hàng>.png
  String _generateFileName() {
    final customerName = _sanitizeFileName(widget.orderData.customerName.isNotEmpty
        ? widget.orderData.customerName
        : 'KhachHang');
    final customerPhone = _sanitizeFileName(widget.orderData.customerPhone.isNotEmpty
        ? widget.orderData.customerPhone
        : 'Unknown');
    return 'hoadon.$customerName.$customerPhone.png';
  }

  @override
  void initState() {
    super.initState();
    _selectedInvoiceSize = widget.orderData.status == OrderStatus.completed ? InvoiceSize.SeventyFiveMm : InvoiceSize.A5;
    _loadAllRequiredData();
  }

  Future<void> _loadAllRequiredData() async {
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        _showErrorDialog('Bạn cần đăng nhập để xem hóa đơn.');
      }
      return;
    }

    try {
      final shopSnapshot = await _dbRef.child('nguoidung/${user.uid}/thongtincuahang').get();
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
        shopInfo = ShopInfo(
          name: 'Cửa hàng của bạn',
          phone: '0000000000',
          address: 'Địa chỉ của bạn',
          bankName: '',
          accountNumber: '',
          accountName: '',
          qrCodeUrl: '',
        );
        if (mounted) {
          _showInfoDialog('Chưa có thông tin cửa hàng. Vui lòng cập nhật trong mục cài đặt.');
        }
      }

      BankInfo? bankInfo;
      if (shopInfo.bankName.isNotEmpty && shopInfo.accountNumber.isNotEmpty) {
        bankInfo = BankInfo.fromMap(Map<dynamic, dynamic>.from(shopSnapshot.value as Map));
      }

      final templateSnapshot = await _dbRef.child('nguoidung/${user.uid}/mauhoadon').get();
      InvoiceSize selectedInvoiceSize = InvoiceSize.A5;
      if (templateSnapshot.exists && templateSnapshot.value != null) {
        final templateMap = Map<String, dynamic>.from(templateSnapshot.value as Map);
        final savedSizeString = templateMap['size'] as String?;
        if (savedSizeString != null) {
          selectedInvoiceSize = InvoiceSize.values.firstWhere(
            (e) => e.toString().split('.').last == savedSizeString,
            orElse: () => InvoiceSize.A5,
          );
        }
      }

      if (mounted) {
        setState(() {
          _shopInfo = shopInfo;
          _bankInfo = bankInfo;
          _selectedInvoiceSize = selectedInvoiceSize;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      print('Lỗi khi tải dữ liệu hóa đơn: $e');
      if (mounted) {
        _showErrorDialog('Lỗi khi tải dữ liệu hóa đơn: $e');
        setState(() {
          _shopInfo = ShopInfo(
            name: 'Lỗi tải thông tin',
            phone: '',
            address: '',
            bankName: '',
            accountNumber: '',
            accountName: '',
            qrCodeUrl: '',
          );
          _isLoadingData = false;
        });
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

    return InvoiceData(
      invoiceNumber: widget.orderData.orderId,
      shopInfo: _shopInfo ?? ShopInfo(
        name: 'Cửa hàng của bạn',
        phone: '0000000000',
        address: 'Địa chỉ của bạn',
        bankName: '',
        accountNumber: '',
        accountName: '',
        qrCodeUrl: '',
      ),
      customerInfo: CustomerInfo(
        name: widget.orderData.customerName,
        phone: widget.orderData.customerPhone,
      ),
      items: invoiceItems,
      shippingCost: widget.orderData.shippingCost,
      discount: widget.orderData.discount,
      notes: widget.orderData.notes,
      selectedSize: _selectedInvoiceSize,
    );
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
            if (mounted) {
              _showErrorDialog('Sản phẩm ${item.name} không đủ tồn kho.');
            }
            return false;
          }
          await productRef.update({
            'tonKho': currentStock - item.quantity,
          });
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Không thể cập nhật tồn kho: $e');
      }
      return false;
    }
  }

  Future<void> _updateOrderStatus(OrderStatus status) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    _showProcessingDialog('Đang cập nhật trạng thái đơn hàng...');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          _showErrorDialog('Bạn cần đăng nhập để cập nhật trạng thái đơn hàng.');
        }
        return;
      }

      if (status == OrderStatus.completed) {
        bool inventoryUpdated = await _updateInventory();
        if (!inventoryUpdated) {
          if (mounted) {
            setState(() => _isProcessing = false);
          }
          return;
        }
      }

      await _dbRef
          .child('nguoidung/${user.uid}/donhang/${widget.orderData.status.toString().split('.').last}/${widget.orderData.orderId}')
          .remove();
      await _dbRef
          .child('nguoidung/${user.uid}/donhang/${status.toString().split('.').last}/${widget.orderData.orderId}')
          .set(widget.orderData.toMap());

      if (mounted) {
        _showSuccessDialog('Đã cập nhật trạng thái đơn hàng thành công!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Lỗi khi cập nhật trạng thái đơn hàng: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<Map<String, dynamic>> _generateInvoiceImage() async {
    try {
      final imageBytes = await SaveImageService.captureWidget(_invoiceKey, pixelRatio: 3.0);
      if (imageBytes == null) {
        return {'isSuccess': false, 'error': 'Không thể tạo ảnh hóa đơn.'};
      }
      final directory = await getTemporaryDirectory();
      final String fileName = _generateFileName();
      final String imagePath = '${directory.path}/$fileName';
      final File imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);
      return {'isSuccess': true, 'imagePath': imagePath, 'fileName': fileName};
    } catch (e) {
      return {'isSuccess': false, 'error': 'Lỗi khi tạo ảnh hóa đơn: $e'};
    }
  }

  Future<void> _saveInvoiceAsImage() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    _showProcessingDialog('Đang lưu ảnh hóa đơn...');

    try {
      final result = await SaveImageService.saveImageToGallery(_invoiceKey, fileName: _generateFileName());
      if (result['isSuccess'] == true) {
        if (mounted) {
          _showSuccessDialog(result['message'] ?? 'Đã lưu ảnh hóa đơn!');
        }
      } else {
        if (mounted) {
          _showErrorDialog(result['error'] ?? 'Không thể lưu ảnh vào thư viện ảnh. Vui lòng kiểm tra quyền truy cập hoặc dung lượng lưu trữ.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Lỗi khi lưu ảnh: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _shareImage() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    _showProcessingDialog('Đang chuẩn bị chia sẻ hóa đơn...');

    try {
      final result = await _generateInvoiceImage();
      if (!result['isSuccess']) {
        if (mounted) {
          _showErrorDialog(result['error'] ?? 'Không thể tạo ảnh hóa đơn để chia sẻ.');
        }
        return;
      }

      final String imagePath = result['imagePath'];
      final String fileName = result['fileName'];
      final String subject = 'Hóa đơn ${widget.orderData.orderId}';
      final String text = 'Hóa đơn từ ${_shopInfo?.name ?? "Cửa hàng của bạn"}';

      try {
        await Share.shareXFiles(
          [XFile(imagePath, mimeType: 'image/png', name: fileName)],
          text: text,
          subject: subject,
        );
        if (mounted) {
          _showSuccessDialog('Đã chia sẻ thành công!');
        }
      } catch (e) {
        final Uri driveUrl = Uri.parse('https://drive.google.com');
        if (await canLaunchUrl(driveUrl)) {
          await launchUrl(driveUrl, mode: LaunchMode.externalApplication);
          if (mounted) {
            _showSuccessDialog('Ứng dụng Google Drive không được cài đặt. Đã mở trang web Google Drive. Vui lòng tải lên ảnh hóa đơn thủ công tại: $imagePath');
          }
        } else {
          if (mounted) {
            _showErrorDialog('Không thể mở Google Drive. Vui lòng kiểm tra kết nối hoặc cài đặt ứng dụng. Ảnh hóa đơn được lưu tại: $imagePath');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Lỗi khi chia sẻ hóa đơn: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportPDF() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    _showProcessingDialog('Đang xuất PDF...');

    try {
      final imageBytes = await SaveImageService.captureWidget(_invoiceKey, pixelRatio: _selectedInvoiceSize == InvoiceSize.A5 ? 5.0 : 3.0);
      if (imageBytes == null) {
        if (mounted) {
          _showErrorDialog('Không thể tạo ảnh hóa đơn để xuất PDF.');
        }
        return;
      }

      final pdf = pw.Document();
      final imageProvider = pw.MemoryImage(imageBytes);
      final pageFormat = _selectedInvoiceSize == InvoiceSize.A5
          ? PdfPageFormat.a5
          : PdfPageFormat(75 * PdfPageFormat.mm, 297 * PdfPageFormat.mm);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Image(imageProvider, fit: pw.BoxFit.contain);
          },
        ),
      );

      bool permissionGranted = await _requestStoragePermission();
      if (!permissionGranted) {
        if (mounted) {
          _showErrorDialog('Bạn cần cấp quyền truy cập bộ nhớ để xuất PDF.');
        }
        return;
      }

      String downloadsPath;
      if (Platform.isAndroid) {
        downloadsPath = '/storage/emulated/0/Download';
      } else {
        final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        downloadsPath = directory.path;
      }

      final String fileName = _generateFileName().replaceAll('.png', '.pdf');
      final String pdfPath = '$downloadsPath/$fileName';
      final File pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      if (mounted) {
        _showSuccessDialog('Đã xuất file PDF tại: $pdfPath');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Lỗi khi xuất PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      return status.isGranted;
    }
    return true;
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.question_mark, color: Colors.blue.shade600, size: 28),
                  const SizedBox(width: 12),
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Hủy'),
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
    );
    return result ?? false;
  }

  void _showProcessingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 12),
                  const Text('Đang xử lý', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    Navigator.of(context).pop(); // Close processing dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                  const SizedBox(width: 12),
                  const Text('Thành công', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 14)),
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
    Navigator.of(context).pop(); // Close processing dialog if open
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade600, size: 28),
                  const SizedBox(width: 12),
                  const Text('Lỗi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 14)),
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

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 28),
                  const SizedBox(width: 12),
                  const Text('Thông báo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Xem & Quản lý Hóa đơn',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  Container(
                    color: Colors.grey.shade100,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: GestureDetector(
                        onScaleStart: (details) {
                          _baseScale = _scale;
                          _baseOffset = _offset;
                        },
                        onScaleUpdate: (details) {
                          if (!_isProcessing) {
                            setState(() {
                              _scale = (_baseScale * details.scale).clamp(0.5, 3.0);
                              _offset = _baseOffset + details.focalPointDelta;
                            });
                          }
                        },
                        onDoubleTap: () {
                          if (!_isProcessing) {
                            setState(() {
                              _scale = 1.0;
                              _offset = Offset.zero;
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade300,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
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
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 15),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 243, 243, 243),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 171, 171, 171),
                          blurRadius: 2,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                           // Thay thế GridView.count
                         child: LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints constraints) {
                              // Tính toán chiều rộng của mỗi nút dựa trên tổng chiều rộng của màn hình
                              // và giới hạn tối đa là 130.0
                              final buttonWidth = (constraints.maxWidth - 15) / 2 > 150 ? 150.0 : (constraints.maxWidth - 15) / 2;
                              final buttonHeight = buttonWidth / 3;
                              return Wrap(
                                spacing: 15,
                                runSpacing: 15,
                                alignment: WrapAlignment.center,
                                children: [
                                  SizedBox(
                                    width: buttonWidth,
                                    height: buttonHeight,
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing ? null : _saveInvoiceAsImage,
                                      icon: const Icon(Icons.image, size: 20),
                                      label: const Text('Lưu ảnh', style: TextStyle(fontSize: 14)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: buttonWidth,
                                    height: buttonHeight,
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing ? null : () => _updateOrderStatus(OrderStatus.saved),
                                      icon: const Icon(Icons.save, size: 20),
                                      label: const Text('Lưu đơn', style: TextStyle(fontSize: 14)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: buttonWidth,
                                    height: buttonHeight,
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing ? null : _exportPDF,
                                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                                      label: const Text('Xuất PDF', style: TextStyle(fontSize: 14)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(255, 247, 38, 35),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: buttonWidth,
                                    height: buttonHeight,
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing ? null : _shareImage,
                                      icon: const Icon(Icons.share, size: 20),
                                      label: const Text('Chia sẻ ảnh', style: TextStyle(fontSize: 14)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(255, 255, 127, 42),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 2,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                  ),
                ],
              ),
            ),
    );
  }
}