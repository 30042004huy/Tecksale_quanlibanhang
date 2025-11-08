// lib/screens/thanhtoan.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/donhang_model.dart' hide FormatCurrency;
import '../models/congno_model.dart';
import '../services/vietqr_service.dart';
import '../utils/format_currency.dart';
import 'taohoadon.dart';
import 'congno.dart';
import 'taodon.dart';
import '../services/custom_notification_service.dart';
import '../services/invoice_number_service.dart';
import '../widgets/calculator_popup.dart';
import 'package:google_fonts/google_fonts.dart'; // Thêm import này

class ThanhToanScreen extends StatefulWidget {
  final OrderData orderData;

  const ThanhToanScreen({Key? key, required this.orderData}) : super(key: key);

  @override
  State<ThanhToanScreen> createState() => _ThanhToanScreenState();
}

class _ThanhToanScreenState extends State<ThanhToanScreen> {
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;
  bool _isProcessing = false;
  bool _isCheckingInvoice = false;
  late Future<Uint8List?> _qrCodeFuture;
  bool _isPartialDebtMode = false;
  final _prepaidAmountController = TextEditingController();
  String _prepaidAmountInWords = 'Không đồng';

  @override
  void initState() {
    super.initState();
    _qrCodeFuture = VietQRService.generateQrCode(amount: widget.orderData.totalAmount);
  }

  void _showCalculator() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const CalculatorPopup();
      },
    );
  }

  void _handleSuccess(String message) {
    if (!mounted) return;
    CustomNotificationService.show(context, message: message);
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TaoDonScreen()),
      (Route<dynamic> route) => route.isFirst,
    );
  }

    Future<bool> _checkInvoiceExists(String orderId) async {
    if (user == null) return false;
    try {
      final uid = user!.uid;
      final savedSnapshot = await dbRef.child('nguoidung/$uid/donhang/saved/$orderId').get();
      final completedSnapshot = await dbRef.child('nguoidung/$uid/donhang/completed/$orderId').get();
      return savedSnapshot.exists || completedSnapshot.exists;
    } catch (e) {
      print('Lỗi kiểm tra số hóa đơn: $e');
      return true;
    }
  }

  void _updatePrepaidAmountInWords(String value) {
    final amount = double.tryParse(value) ?? 0;
    if (amount > widget.orderData.totalAmount) {
      _prepaidAmountController.text = widget.orderData.totalAmount.toStringAsFixed(0);
      _prepaidAmountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _prepaidAmountController.text.length),
      );
      setState(() {
        _prepaidAmountInWords = FormatCurrency.numberToWords(widget.orderData.totalAmount);
      });
      return;
    }
    setState(() {
      _prepaidAmountInWords = FormatCurrency.numberToWords(amount);
    });
  }


  Future<void> _handlePartialDebt() async {
    if (_isProcessing) return;

    final prepaidAmount = double.tryParse(_prepaidAmountController.text) ?? 0;
    if (prepaidAmount <= 0) {
      CustomNotificationService.show(context, message: 'Vui lòng nhập số tiền trả trước.', textColor: Colors.red);
      return;
    }

    final remainingDebt = widget.orderData.totalAmount - prepaidAmount;
    if (remainingDebt < 0) {
      CustomNotificationService.show(context, message: 'Số tiền trả trước không hợp lệ.', textColor: Colors.red);
      return;
    }

    final orderId = widget.orderData.orderId;
    if (await _checkInvoiceExists(orderId)) {
      if (mounted) {
        CustomNotificationService.show(context, message: 'Số hóa đơn "$orderId" đã tồn tại.', textColor: Colors.red);
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (user == null) throw Exception('Người dùng chưa đăng nhập.');
      await InvoiceNumberService.incrementInvoiceCounter();

      final paymentNote = 'Trả trước: ${FormatCurrency.format(prepaidAmount)}';
      final existingNote = widget.orderData.notes;
      final combinedNote = existingNote.isNotEmpty ? '$existingNote\n$paymentNote' : paymentNote;

      final updatedOrderData = widget.orderData.copyWith(
        status: OrderStatus.saved,
        notes: combinedNote,
      );
      
      await dbRef.child('nguoidung/${user!.uid}/donhang/saved/${widget.orderData.orderId}').set(updatedOrderData.toMap());

      final congNoRef = dbRef.child('nguoidung/${user!.uid}/congno').push();
      final congNoData = CongNoModel(
        id: congNoRef.key!,
        orderId: widget.orderData.orderId,
        customerName: widget.orderData.displayCustomerName, // ✨ SỬA
        customerPhone: widget.orderData.displayCustomerPhone, // ✨ SỬA
        amount: remainingDebt,
        debtDate: DateTime.now(),
        status: CongNoStatus.chuaTra,
        notes: paymentNote,
      );
      await congNoRef.set(congNoData.toMap());

      _handleSuccess('Đã ghi nợ một phần thành công!');
    } catch (e) {
      _showErrorDialog('Lỗi khi ghi nợ: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleLuuDon() async {
    if (_isProcessing) return;
    final orderId = widget.orderData.orderId;
    if (await _checkInvoiceExists(orderId)) {
      if (mounted) {
        CustomNotificationService.show(
          context,
          message: 'Số hóa đơn "$orderId" đã tồn tại. Vui lòng sửa lại.',
          textColor: Colors.red,
        );
      }
      return;
    }
    setState(() => _isProcessing = true);

    try {
      if (user == null) throw Exception('Người dùng chưa đăng nhập.');
      await InvoiceNumberService.incrementInvoiceCounter();

      final updatedOrderData = widget.orderData.copyWith(status: OrderStatus.saved);

      final orderRef = dbRef.child('nguoidung/${user!.uid}/donhang/saved/${widget.orderData.orderId}');
      await orderRef.set(updatedOrderData.toMap());

      _handleSuccess('Đã lưu đơn hàng thành công!');
    } catch (e) {
      _showErrorDialog('Lỗi khi lưu đơn: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleGhiNo() async {
    if (_isProcessing) return;
    final orderId = widget.orderData.orderId;
    if (await _checkInvoiceExists(orderId)) {
      if (mounted) {
        CustomNotificationService.show(
          context,
          message: 'Số hóa đơn "$orderId" đã tồn tại. Vui lòng sửa lại.',
          textColor: Colors.red,
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      if (user == null) throw Exception('Người dùng chưa đăng nhập.');
      await InvoiceNumberService.incrementInvoiceCounter();

      final updatedOrderData = widget.orderData.copyWith(status: OrderStatus.saved);

      final orderRef = dbRef.child('nguoidung/${user!.uid}/donhang/saved/${widget.orderData.orderId}');
      await orderRef.set(updatedOrderData.toMap());

      final congNoRef = dbRef.child('nguoidung/${user!.uid}/congno').push();
      final congNoData = CongNoModel(
        id: congNoRef.key!,
        orderId: widget.orderData.orderId,
        customerName: widget.orderData.displayCustomerName, // ✨ SỬA
        customerPhone: widget.orderData.displayCustomerPhone, // ✨ SỬA
        amount: widget.orderData.totalAmount,
        debtDate: DateTime.now(),
        status: CongNoStatus.chuaTra,
      );
      await congNoRef.set(congNoData.toMap());
      _handleSuccess('Đã ghi nợ thành công!');
    } catch (e) {
      _showErrorDialog('Lỗi khi ghi nợ: $e');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ✨ YÊU CẦU 2: POPUP XÁC NHẬN CHUYÊN NGHIỆP ✨
  Future<void> _showHoanTatConfirmationDialog() async {
    if (_isProcessing) return;

    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Giúp icon và chữ căn lề trên
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 28),
              const SizedBox(width: 12),
              // Bọc Text bằng Expanded để tự động xuống dòng
              Expanded( 
                child: Text(
                  'Xác nhận Hoàn tất',
                  style: GoogleFonts.quicksand(fontWeight: FontWeight.bold,fontSize: 19),
                ),
              ),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn hoàn tất đơn hàng này?',
            style: GoogleFonts.roboto(fontSize: 16),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Trả về false
              child: Text(
                'HỦY BỎ',
                style: GoogleFonts.roboto(color: Colors.grey.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('XÁC NHẬN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(true), // Trả về true
            ),
          ],
        );
      },
    );

    // Nếu người dùng xác nhận (didConfirm == true) thì mới chạy logic
    if (didConfirm == true) {
      await _handleHoanTatDon();
    }
  }

  // Hàm logic gốc, giờ được gọi từ popup
  Future<void> _handleHoanTatDon() async {
    if (_isProcessing) return;

    final orderId = widget.orderData.orderId;
    if (await _checkInvoiceExists(orderId)) {
      if (mounted) {
        CustomNotificationService.show(
          context,
          message: 'Số hóa đơn "$orderId" đã tồn tại. Vui lòng sửa lại.',
          textColor: Colors.red,
        );
      }
      return;
    }

    setState(() => _isProcessing = true);
    // Hiển thị dialog xử lý ngay
    _showProcessingDialog('Đang hoàn tất đơn hàng...');

    try {
      if (user == null) throw Exception('Người dùng chưa đăng nhập.');
      await InvoiceNumberService.incrementInvoiceCounter();
      await dbRef.child('nguoidung/${user!.uid}/donhang/saved/${widget.orderData.orderId}').remove();
      final updatedOrder = widget.orderData.copyWith(status: OrderStatus.completed, savedAt: ServerValue.timestamp); // Thêm savedAt
      final orderRef = dbRef.child('nguoidung/${user!.uid}/donhang/completed/${widget.orderData.orderId}');
      await orderRef.set(updatedOrder.toMap());
      
      // Đóng dialog xử lý
      if (mounted && Navigator.canPop(context)) Navigator.of(context).pop();
      _handleSuccess('Đã hoàn tất đơn hàng!');

    } catch (e) {
       _showErrorDialog('Lỗi khi hoàn tất đơn: $e');
       if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Hàm hiển thị dialog xử lý (cần thiết cho _handleHoanTatDon)
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
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thanh toán'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
                   actions: [
            Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: tabController,
                  builder: (context, child) {
                    if (tabController.index == 1) {
                      return IconButton(
                        icon: const Icon(Icons.calculate),
                        onPressed: _showCalculator,
                        tooltip: 'Mở máy tính',
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.yellow,
            tabs: [
              Tab(icon: Icon(Icons.qr_code_2), text: 'VietQR'),
              Tab(icon: Icon(Icons.money), text: 'Tiền mặt'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'QRCode'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: Colors.blue.shade50,
              child: Column(
                children: [
                  const Text('TỔNG THANH TOÁN', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    FormatCurrency.format(widget.orderData.totalAmount),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: VietQR
                  Center(
                    child: FutureBuilder<Uint8List?>(
                      future: _qrCodeFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (snapshot.hasError || snapshot.data == null) {
                          return const Text('Không thể tạo mã QR. Vui lòng kiểm tra thông tin ngân hàng.', textAlign: TextAlign.center);
                        }
                        return Image.memory(snapshot.data!, width: 250);
                      },
                    ),
                  ),
                  // Tab 2: Tiền mặt
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            // ✨ YÊU CẦU 2: GỌI DIALOG XÁC NHẬN
                            onPressed: _isProcessing ? null : _showHoanTatConfirmationDialog,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Thanh toán đủ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _handleGhiNo,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Ghi nợ toàn bộ'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: _isProcessing ? null : () {
                              setState(() {
                                _isPartialDebtMode = !_isPartialDebtMode;
                                _prepaidAmountController.clear();
                                _prepaidAmountInWords = 'Không đồng';
                              });
                            },
                            icon: Icon(_isPartialDebtMode ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                            label: const Text('Nợ một phần'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(color: Colors.deepPurple),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                          ),
                          if (_isPartialDebtMode)
                            Container(
                              margin: const EdgeInsets.only(top: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                // ✨ YÊU CẦU 3: Bỏ viền ngoài, thêm nền nhạt
                                color: Colors.deepPurple.shade50.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _prepaidAmountController,
                                    keyboardType: TextInputType.number,
                                    // ✨ YÊU CẦU 3: CẬP NHẬT DECORATION
                                    decoration: InputDecoration(
                                      labelText: 'Nhập số tiền trả trước',
                                      suffixText: 'đ',
                                      // Viền khi không focus
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.deepPurple.shade200, width: 1.0),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      // Viền khi focus
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.deepPurple, width: 2.0),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      // Border mặc định (cho trường hợp lỗi, v.v.)
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    onChanged: _updatePrepaidAmountInWords,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _prepaidAmountInWords,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _isProcessing ? null : _handlePartialDebt,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('Lưu Nợ Một Phần'),
                                  )
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Tab 3: QRCode
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.developer_mode, size: 50, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Tính năng đang phát triển',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildActionButtons(),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(Icons.save, 'Lưu đơn', Colors.blue, _handleLuuDon),
          _buildActionButton(Icons.receipt_long, 'Hóa đơn', Colors.green, () {
            if (_isProcessing) return;
            showModalBottomSheet(
              context: context,
              isScrollControlled: true, 
              backgroundColor: Colors.transparent,
              builder: (context) {
                // Gọi TaoHoaDonScreen ở chế độ modal
                return TaoHoaDonScreen(
                  orderData: widget.orderData,
                  isModal: true, 
                );
              },
            );
          }),
          _buildActionButton(Icons.print, 'In đơn', Colors.orange, () {
            CustomNotificationService.show(
              context,
              message: 'Chưa kết nối được tới máy in',
              textColor: Colors.orange.shade800,
            );
          }),
          // ✨ YÊU CẦU 2: GỌI DIALOG XÁC NHẬN
          _buildActionButton(Icons.check, 'Hoàn tất', Colors.red, _showHoanTatConfirmationDialog),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: color, size: 28),
          onPressed: _isProcessing ? null : onPressed,
        ),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

   void _showErrorDialog(String message) {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }
}