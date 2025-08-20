import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/mauhoadon_model.dart'; // Import model hóa đơn
import '../widgets/uimauhoadon/uimauhoadona5.dart'; // Import mẫu A5
import '../widgets/uimauhoadon/uimauhoadon75mm.dart'; // Đã cập nhật import cho mẫu 75mm

class MauHoaDonScreen extends StatefulWidget {
  const MauHoaDonScreen({super.key});

  @override
  State<MauHoaDonScreen> createState() => _MauHoaDonScreenState();
}

class _MauHoaDonScreenState extends State<MauHoaDonScreen> {
  InvoiceSize _selectedSize = InvoiceSize.A5; // Chỉ cần chọn kích thước
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mẫu hóa đơn',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Size selection
          Container(
            padding: const EdgeInsets.all(20), // Đã khôi phục padding
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn kích thước hóa đơn:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15), // Đã khôi phục khoảng cách
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSize = InvoiceSize.A5;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10), // Giữ nguyên padding của nút
                          decoration: BoxDecoration(
                            color: _selectedSize == InvoiceSize.A5
                                ? Colors.blue.shade50
                                : Colors.grey.shade50,
                            border: Border.all(
                              color: _selectedSize == InvoiceSize.A5
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.description,
                                size: 30, // Giữ nguyên kích thước icon
                                color: _selectedSize == InvoiceSize.A5
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(height: 6), // Giữ nguyên khoảng cách
                              Text(
                                'A5',
                                style: TextStyle(
                                  fontSize: 14, // Giữ nguyên font size
                                  fontWeight: FontWeight.bold,
                                  color: _selectedSize == InvoiceSize.A5
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '210 x 148 mm',
                                style: TextStyle(
                                  fontSize: 10, // Giữ nguyên font size
                                  color: _selectedSize == InvoiceSize.A5
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // Giữ nguyên khoảng cách giữa 2 nút
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSize = InvoiceSize.SeventyFiveMm;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10), // Giữ nguyên padding của nút
                          decoration: BoxDecoration(
                            color: _selectedSize == InvoiceSize.SeventyFiveMm
                                ? Colors.blue.shade50
                                : Colors.grey.shade50,
                            border: Border.all(
                              color: _selectedSize == InvoiceSize.SeventyFiveMm
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 30, // Giữ nguyên kích thước icon
                                color: _selectedSize == InvoiceSize.SeventyFiveMm
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(height: 6), // Giữ nguyên khoảng cách
                              Text(
                                '75mm',
                                style: TextStyle(
                                  fontSize: 14, // Giữ nguyên font size
                                  fontWeight: FontWeight.bold,
                                  color: _selectedSize == InvoiceSize.SeventyFiveMm
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                'Thermal Printer',
                                style: TextStyle(
                                  fontSize: 10, // Giữ nguyên font size
                                  color: _selectedSize == InvoiceSize.SeventyFiveMm
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Preview area
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20), // Đã khôi phục padding
                  child: _buildInvoicePreview(),
                ),
              ),
            ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.all(20), // Đã khôi phục padding
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTemplate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15), // Đã khôi phục padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20, // Đã khôi phục kích thước loading indicator
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Lưu mẫu hóa đơn',
                        style: TextStyle(
                          fontSize: 16, // Đã khôi phục font size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicePreview() {
    // Sample data for preview
    final previewData = InvoiceData(
      invoiceNumber: 'HD20241201001',
      shopInfo: ShopInfo(
        name: 'Cửa hàng TechSale',
        phone: '0123456789',
        address: 'Thanh Xuân, Hà NộiNội',
        bankName: 'Vietcombank',
        accountNumber: '1234567890',
        accountName: 'CÔNG TY TNHH TECHSALE',
        qrCodeUrl: 'https://placehold.co/200x200/000000/FFFFFF/png?text=QR+Code',
      ),
      customerInfo: CustomerInfo(
        name: 'Nguyễn Văn A',
        phone: '0987654321',
      ),
      items: [
        InvoiceItem(
          name: 'iPhone 15 Pro Max',
          quantity: 1,
          unitPrice: 25000000,
          unit: 'Chiếc',
        ),
        InvoiceItem(
          name: 'Tai nghe AirPods Pro',
          quantity: 2,
          unitPrice: 5000000,
          unit: 'Chiếc',
        ),
      ],
      shippingCost: 50000,
      discount: 1000000,
      notes: 'Giao hàng trong ngày',
      selectedSize: _selectedSize, // Cập nhật kích thước hóa đơn mẫu
    );

    if (_selectedSize == InvoiceSize.A5) {
      return UIMauHoaDonA5(invoiceData: previewData);
    } else {
      return UIMauHoaDon75mm(invoiceData: previewData);
    }
  }

  Future<void> _saveTemplate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('Vui lòng đăng nhập để lưu mẫu hóa đơn');
        return;
      }

      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('nguoidung/${user.uid}/mauhoadon').set({
        'size': _selectedSize.toString().split('.').last, // Lưu tên enum
        'savedAt': ServerValue.timestamp,
      });

      _showSuccessDialog('Mẫu hóa đơn đã được lưu thành công!');
    } catch (e) {
      _showErrorDialog('Lỗi khi lưu mẫu hóa đơn: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thành công'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
