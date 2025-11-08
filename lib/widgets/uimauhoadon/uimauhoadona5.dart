import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../models/mauhoadon_model.dart';
import '../../../services/vietqr_service.dart';

class UIMauHoaDonA5 extends StatefulWidget {
  final InvoiceData invoiceData;

  const UIMauHoaDonA5({
    Key? key,
    required this.invoiceData,
  }) : super(key: key);

  @override
  _UIMauHoaDonA5State createState() => _UIMauHoaDonA5State();
}

class _UIMauHoaDonA5State extends State<UIMauHoaDonA5> {
  Uint8List? _qrCodeData;

  @override
  void initState() {
    super.initState();
    _generateQrCode();
  }

  // Reload QR code if invoice data changes (e.g., total amount)
  @override
  void didUpdateWidget(covariant UIMauHoaDonA5 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invoiceData.totalPayment != oldWidget.invoiceData.totalPayment) {
      _generateQrCode();
    }
  }

  Future<void> _generateQrCode() async {
    if (widget.invoiceData.totalPayment > 0) {
      try {
        final qrData = await VietQRService.generateQrCode(
          amount: widget.invoiceData.totalPayment,
        );
        if (mounted) {
          setState(() {
            _qrCodeData = qrData;
          });
        }
      } catch (e) {
        // Handle error silently or log it
      }
    }
  }

  Widget _buildInfoRow(String label, String value,
      {double fontSize = 7,
      FontWeight fontWeight = FontWeight.w500,
      Color? valueColor,
      int labelFlex = 2,
      int valueFlex = 5}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: valueFlex,
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: valueColor ?? Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, {bool isCentered = false}) {
    return Column(
      crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color.fromARGB(255, 66, 66, 66), width: 0.5),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 0),
        ...children,
      ],
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 10 : 8,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            FormatCurrency.formatCurrency(amount),
            style: TextStyle(
              fontSize: isTotal ? 10 : 8,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.red.shade700 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 419.52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            if (widget.invoiceData.showShopInfo)
              Column(
                children: [
                  Text(
                    widget.invoiceData.shopInfo.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 1),
                ],
              ),
            
            Text(
              'HÓA ĐƠN BÁN HÀNG',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 196, 0, 0),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),

            // Shop and Customer Info
            if (widget.invoiceData.showShopInfo || widget.invoiceData.showCustomerInfo)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.invoiceData.showShopInfo)
                    Expanded(
                      flex: 2,
                      child: _buildInfoSection('THÔNG TIN CỬA HÀNG', [
                        _buildInfoRow('Điện thoại:', widget.invoiceData.shopInfo.phone, labelFlex: 2, valueFlex: 7),
                        _buildInfoRow('Địa chỉ:', widget.invoiceData.shopInfo.address, labelFlex: 2, valueFlex: 10),
                         if (widget.invoiceData.employeeName?.isNotEmpty ?? false)
                          _buildInfoRow('Nhân viên:', widget.invoiceData.employeeName!, labelFlex: 2, valueFlex: 7),
                      ]),
                    ),
                  if (widget.invoiceData.showShopInfo && widget.invoiceData.showCustomerInfo)
                    const SizedBox(width: 6),
                  if (widget.invoiceData.showCustomerInfo)
                    Expanded(
                      flex: 1,
                      child: _buildInfoSection('THÔNG TIN KHÁCH HÀNG', [
                        _buildInfoRow('Tên KH:', widget.invoiceData.customerInfo.name, labelFlex: 3, valueFlex: 7),
                        _buildInfoRow('SĐT:', widget.invoiceData.customerInfo.phone, labelFlex: 3, valueFlex: 10),
                      ]),
                    ),
                ],
              ),
            if (widget.invoiceData.showShopInfo || widget.invoiceData.showCustomerInfo)
              const SizedBox(height: 15),

            // Invoice Info
            Align(
              alignment: Alignment.center,
              child: _buildInfoSection('THÔNG TIN HÓA ĐƠN', [
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text( 'Số HĐ: ', style: TextStyle( fontSize: 7, fontWeight: FontWeight.w600, color: Colors.black)),
                    Text( widget.invoiceData.invoiceNumber, style: TextStyle( fontSize: 7, fontWeight: FontWeight.w800, color: Colors.red.shade700)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text( 'Ngày: ', style: TextStyle( fontSize: 7, fontWeight: FontWeight.w600, color: Colors.black)),
                    Text(
                      DateFormat('dd/MM/yyyy').format(widget.invoiceData.orderDate ?? DateTime.now()),
                      style: const TextStyle( fontSize: 7, fontWeight: FontWeight.w500, color: Colors.black),
                    ),
                  ],
                ),
              ], isCentered: true),
            ),
            const SizedBox(height: 15),

            // Product Items Table
            Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 13, child: Text('TÊN SẢN PHẨM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black))),
                      Expanded(flex: 3, child: Text('SL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), textAlign: TextAlign.center)),
                      Expanded(flex: 4, child: Text('ĐƠN VỊ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), textAlign: TextAlign.center)),
                      Expanded(flex: 6, child: Text('ĐƠN GIÁ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), textAlign: TextAlign.right)),
                      Expanded(flex: 7, child: Text('THÀNH TIỀN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                // Table Rows
                Column(
                  children: widget.invoiceData.items.map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.black, width: 0.5),
                          left: BorderSide(color: Colors.black, width: 1),
                          right: BorderSide(color: Colors.black, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded( flex: 13, child: Text(item.name, style: const TextStyle(fontSize: 6, color: Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          Expanded( flex: 3, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 6, color: Colors.black))),
                          Expanded( flex: 4, child: Text(item.unit, textAlign: TextAlign.center, style: const TextStyle(fontSize: 6, color: Colors.black))),
                          Expanded( flex: 6, child: Text(FormatCurrency.formatCurrency(item.unitPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 6, color: Colors.black))),
                          Expanded( flex: 7, child: Text(FormatCurrency.formatCurrency(item.totalPrice), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Summary and Payment Info
            Column(
              children: [
                // Total Summary
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.black, width: 0.5)),
                  ),
                  child: Column(
                    children: [
                      _buildTotalRow('Tổng tiền hàng:', widget.invoiceData.subtotal),
                      if (widget.invoiceData.shippingCost > 0)
                        _buildTotalRow('Phí vận chuyển:', widget.invoiceData.shippingCost),
                      if (widget.invoiceData.discount > 0)
                        _buildTotalRow('Giảm giá:', -widget.invoiceData.discount, isDiscount: true),
                      Container( margin: const EdgeInsets.symmetric(vertical: 2), height: 0.5, color: Colors.black),
                      _buildTotalRow('TỔNG CỘNG:', widget.invoiceData.totalPayment, isTotal: true),
                      const SizedBox(height: 1),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Bằng chữ: ${widget.invoiceData.totalPaymentInWords}',
                          style: const TextStyle(fontSize: 7, fontStyle: FontStyle.italic, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Notes
                if (widget.invoiceData.notes.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ghi chú:', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                        const SizedBox(height: 2),
                        Text(widget.invoiceData.notes, style: const TextStyle(fontSize: 7, color: Colors.black)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Payment Info & QR Code
if (widget.invoiceData.showBankInfo || widget.invoiceData.showQrCode)
  Container(
    padding: const EdgeInsets.all(6),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.black, width: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('THÔNG TIN THANH TOÁN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✨ THÊM ĐIỀU KIỆN CHO THÔNG TIN NGÂN HÀNG
            if (widget.invoiceData.showBankInfo)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPaymentInfo('Ngân hàng:', widget.invoiceData.shopInfo.bankName),
                    _buildPaymentInfo('Số tài khoản:', widget.invoiceData.shopInfo.accountNumber),
                    _buildPaymentInfo('Chủ tài khoản:', widget.invoiceData.shopInfo.accountName),
                  ],
                ),
              ),
            
            // Thêm khoảng cách nếu cả 2 đều hiển thị
            if (widget.invoiceData.showBankInfo && widget.invoiceData.showQrCode)
              const SizedBox(width: 1),

            // ✨ THÊM ĐIỀU KIỆN CHO MÃ QR
            if (widget.invoiceData.showQrCode)
              Expanded(
                flex: 1,
                child: _qrCodeData == null
                    ? const Column(
                        children: [ Center( child: SizedBox( width: 35, height: 35, child: CircularProgressIndicator(strokeWidth: 2)))],
                      )
                    : Column(
                        children: [
                          const Text('QUÉT MÃ QR', style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.black)),
                          const SizedBox(height: 1),
                          Image.memory(_qrCodeData!, width: 85, height: 85),
                        ],
                      ),
              ),
          ],
        ),
      ],
    ),
  ),
                const SizedBox(height: 6),

                // Footer - Thank You
                if (widget.invoiceData.showShopInfo)
                  Text(
                    '${widget.invoiceData.shopInfo.name} - Cảm ơn quý khách đã mua hàng! Hẹn gặp lại!',
                    style: const TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
