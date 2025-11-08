import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../models/mauhoadon_model.dart';
import '../services/custom_notification_service.dart';
import '../widgets/uimauhoadon/uimauhoadona5.dart';
import '../widgets/uimauhoadon/uimauhoadon75mm.dart';

class MauHoaDonScreen extends StatefulWidget {
  const MauHoaDonScreen({super.key});

  @override
  State<MauHoaDonScreen> createState() => _MauHoaDonScreenState();
}

class _MauHoaDonScreenState extends State<MauHoaDonScreen> {
  InvoiceSize _selectedSize = InvoiceSize.A5;
  bool _showShopInfo = true;
  bool _showCustomerInfo = true;
  bool _showBankInfo = true;
  bool _showQrCode = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseDatabase.instance.ref('nguoidung/${user.uid}/mauhoadon').get();
      if (snapshot.exists && mounted) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _selectedSize = (data['size'] == 'SeventyFiveMm') ? InvoiceSize.SeventyFiveMm : InvoiceSize.A5;
          _showShopInfo = data['showShopInfo'] ?? true;
          _showCustomerInfo = data['showCustomerInfo'] ?? true;
          _showBankInfo = data['showBankInfo'] ?? true;
          _showQrCode = data['showQrCode'] ?? true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTemplate() async {
    setState(() => _isLoading = true);
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // ✨ SỬA LẠI CÁCH GỌI THÔNG BÁO
        CustomNotificationService.show(context, message: 'Vui lòng đăng nhập để lưu.', textColor: Colors.red.shade600);
        return;
      }
      
      await FirebaseDatabase.instance.ref('nguoidung/${user.uid}/mauhoadon').set({
        'size': _selectedSize.toString().split('.').last,
        'showShopInfo': _showShopInfo,
        'showCustomerInfo': _showCustomerInfo,
        'showBankInfo': _showBankInfo,
        'showQrCode': _showQrCode,
        'savedAt': ServerValue.timestamp,
      });

      // ✨ SỬA LẠI CÁCH GỌI THÔNG BÁO
      CustomNotificationService.show(context, message: 'Đã lưu cài đặt thành công!');
    } catch (e) {
      // ✨ SỬA LẠI CÁCH GỌI THÔNG BÁO
      CustomNotificationService.show(context, message: 'Lỗi khi lưu: $e', textColor: Colors.red.shade600);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Tùy chỉnh Hóa Đơn', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionCard(
                      title: 'Chọn Kích Thước',
                      child: _buildSizeSelector(),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Tùy Chọn Hiển Thị',
                      child: _buildDisplayOptions(),
                    ),
                    const SizedBox(height: 20),
                    Text("XEM TRƯỚC HÓA ĐƠN", style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)) ]
                      ),
                      child: _buildInvoicePreview(),
                    ),
                  ],
                ),
              ),
              _buildSaveButton(),
            ],
          ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.quicksand(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeSelector() {
    return Row(
      children: [
        Expanded(child: _buildSizeOption(title: 'A5', subtitle: '210 x 148 mm', size: InvoiceSize.A5)),
        const SizedBox(width: 16),
        Expanded(child: _buildSizeOption(title: '75mm', subtitle: 'Máy in nhiệt', size: InvoiceSize.SeventyFiveMm)),
      ],
    );
  }
  
  Widget _buildSizeOption({required String title, required String subtitle, required InvoiceSize size}) {
    final isSelected = _selectedSize == size;
    return GestureDetector(
      onTap: () => setState(() => _selectedSize = size),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            Text(title, style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.roboto(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayOptions() {
    return Column(
      children: [
        _buildCustomSwitchTile(
          title: 'Thông tin cửa hàng',
          icon: Icons.store_outlined,
          value: _showShopInfo,
          onChanged: (val) => setState(() => _showShopInfo = val),
        ),
        const Divider(height: 1, indent: 56, endIndent: 16),
        _buildCustomSwitchTile(
          title: 'Thông tin khách hàng',
          icon: Icons.person_outline,
          value: _showCustomerInfo,
          onChanged: (val) => setState(() => _showCustomerInfo = val),
        ),
        const Divider(height: 1, indent: 56, endIndent: 16),
        _buildCustomSwitchTile(
          title: 'Thông tin ngân hàng',
          icon: Icons.account_balance_wallet_outlined,
          value: _showBankInfo,
          onChanged: (val) => setState(() => _showBankInfo = val),
        ),
        const Divider(height: 1, indent: 56, endIndent: 16),
        _buildCustomSwitchTile(
          title: 'Mã QR thanh toán',
          icon: Icons.qr_code_2_outlined,
          value: _showQrCode,
          onChanged: (val) => setState(() => _showQrCode = val),
        ),
      ],
    );
  }

  Widget _buildCustomSwitchTile({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final activeColor = Colors.blue.shade800;
    final inactiveColor = Colors.grey.shade500;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (value ? activeColor : inactiveColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: value ? activeColor : inactiveColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blue.shade600,
              activeTrackColor: Colors.blue.shade200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicePreview() {
    final previewData = InvoiceData(
      invoiceNumber: 'HD20251013001',
      shopInfo: ShopInfo(name: 'Cửa hàng TechSale', phone: '0123456789', address: 'Thanh Xuân, Hà Nội', bankName: 'Vietcombank', accountNumber: '1234567890', accountName: 'CÔNG TY TNHH TECHSALE', qrCodeUrl: ''),
      customerInfo: CustomerInfo(name: 'Nguyễn Văn A', phone: '0987654321'),
      items: [
        InvoiceItem(name: 'iPhone 17 Pro', quantity: 1, unitPrice: 35000000, unit: 'Chiếc'),
        InvoiceItem(name: 'Tai nghe Vision Pro', quantity: 1, unitPrice: 90000000, unit: 'Chiếc'),
      ],
      employeeName: 'Trần Văn B',
    ).copyWith( 
      showShopInfo: _showShopInfo,
      showCustomerInfo: _showCustomerInfo,
      showBankInfo: _showBankInfo,
      showQrCode: _showQrCode,
    );

    return _selectedSize == InvoiceSize.A5
        ? UIMauHoaDonA5(invoiceData: previewData)
        : UIMauHoaDon75mm(invoiceData: previewData);
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveTemplate,
            icon: _isLoading ? Container() : const Icon(Icons.save_outlined),
            label: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Text('Lưu Cài Đặt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}