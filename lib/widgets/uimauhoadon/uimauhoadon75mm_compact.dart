// File: widgets/uimauhoadon/uimauhoadon75mm_compact.dart (Đã sửa)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../models/mauhoadon_model.dart';
import '../../../utils/format_currency.dart' as currency_utils;
import '../../../services/vietqr_service.dart';

class UIMauHoaDon75mmCompact extends StatefulWidget {
  final InvoiceData invoiceData;

  const UIMauHoaDon75mmCompact({
    Key? key,
    required this.invoiceData,
  }) : super(key: key);

  @override
  _UIMauHoaDon75mmCompactState createState() => _UIMauHoaDon75mmCompactState();
}

class _UIMauHoaDon75mmCompactState extends State<UIMauHoaDon75mmCompact> {
  Uint8List? _qrCodeData;
  bool _canGenerateQr = false;

  @override
  void initState() {
    super.initState();
    _checkAndGenerateQrCode();
  }

  Future<void> _checkAndGenerateQrCode() async {
    final String bankName = widget.invoiceData.shopInfo.bankName;
    final String accountNumber = widget.invoiceData.shopInfo.accountNumber;
    final double totalAmount = widget.invoiceData.totalPayment;

    _canGenerateQr = bankName.isNotEmpty && accountNumber.isNotEmpty && totalAmount > 0;

    if (_canGenerateQr) {
      try {
        // Gọi service VietQR, chỉ truyền amount. (Giả định service tự fetch info từ Firebase)
        final qrData = await VietQRService.generateQrCode(
          amount: totalAmount,
        );
        if (mounted) {
          setState(() {
            _qrCodeData = qrData;
          });
        }
      } catch (e) {
        // Xử lý lỗi tạo QR code
      }
    }
  }

  Widget _buildInfoRow(String label, String value, {int labelFlex = 3, int valueFlex = 7, double fontSize = 7.5}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: valueFlex,
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 9 : 8,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.red.shade700 : Colors.black,
            ),
          ),
          Text(
            currency_utils.FormatCurrency.format(amount, suffix: ''),
            style: TextStyle(
              fontSize: isTotal ? 9 : 8,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.red.shade700 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailRow(String label, String value, {double fontSize = 7.5}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2), 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double seventyFiveMmWidth = 283.0; // Khoảng 75mm

    final orderDateTime = widget.invoiceData.orderDate ?? DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(orderDateTime); // Format ngày đầy đủ hơn
    final formattedTime = DateFormat('HH:mm:ss').format(orderDateTime); // Format giờ đầy đủ hơn

    return Container(
      width: seventyFiveMmWidth,
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header - Tên cửa hàng và địa chỉ (Ngắn gọn)
          Text(
            widget.invoiceData.shopInfo.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.invoiceData.shopInfo.address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.invoiceData.shopInfo.address,
                style: const TextStyle(fontSize: 7, color: Colors.black),
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
          if (widget.invoiceData.shopInfo.phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                'SĐT: ${widget.invoiceData.shopInfo.phone}',
                style: const TextStyle(fontSize: 7, color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 7), 

          // Tên hóa đơn
          Text(
            'HÓA ĐƠN BÁN HÀNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),

          // Số HĐ và Ngày/Giờ (ĐÃ SỬA: Ngày/Giờ nằm dưới Số HĐ)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Số HĐ
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Số HĐ: ${widget.invoiceData.invoiceNumber}',
                      style: const TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    // Ngày
                    Text(
                      'Ngày: $formattedDate', 
                      style: const TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                // Giờ (Nằm dưới Số HĐ)
                Text(
                  'Giờ: $formattedTime',
                  style: const TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // Thông tin khách hàng và nhân viên
          if (widget.invoiceData.customerInfo.name.isNotEmpty ||
              widget.invoiceData.customerInfo.phone.isNotEmpty ||
              widget.invoiceData.employeeName?.isNotEmpty == true)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.invoiceData.customerInfo.name.isNotEmpty)
                    _buildInfoRow('Khách hàng:', widget.invoiceData.customerInfo.name, labelFlex: 2, valueFlex: 8, fontSize: 7.5),
                  if (widget.invoiceData.customerInfo.phone.isNotEmpty)
                    _buildInfoRow('SĐT:', widget.invoiceData.customerInfo.phone, labelFlex: 2, valueFlex: 8, fontSize: 7.5),
                  if (widget.invoiceData.employeeName?.isNotEmpty == true)
                    _buildInfoRow('Nhân viên:', widget.invoiceData.employeeName!, labelFlex: 2, valueFlex: 8, fontSize: 7.5),
                ],
              ),
            ),
          const SizedBox(height: 5),
          const Divider(color: Colors.black, thickness: 1, height: 1),

          // Danh sách sản phẩm
          _buildItemsTable(widget.invoiceData.items),
          const Divider(color: Colors.black, thickness: 1, height: 1),
          const SizedBox(height: 5),

          // Tổng tiền
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                _buildTotalRow('Tổng tiền hàng:', widget.invoiceData.subtotal),
                if (widget.invoiceData.shippingCost > 0)
                  _buildTotalRow('Phí vận chuyển:', widget.invoiceData.shippingCost),
                if (widget.invoiceData.discount > 0)
                  _buildTotalRow('Giảm giá:', -widget.invoiceData.discount),
                const Divider(color: Colors.black, thickness: 0.5, height: 5),
                _buildTotalRow('TỔNG THANH TOÁN:', widget.invoiceData.totalPayment, isTotal: true),
                const SizedBox(height: 3),
                Text(
                  'Bằng chữ: ${widget.invoiceData.totalPaymentInWords}',
                  style: const TextStyle(
                    fontSize: 7, 
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.left,
                  softWrap: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Ghi chú
          if (widget.invoiceData.notes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ghi chú:', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(
                    widget.invoiceData.notes,
                    style: const TextStyle(fontSize: 7, color: Colors.black),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Thông tin thanh toán (Bank Info & QR Code)
          if (widget.invoiceData.shopInfo.bankName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cột thông tin ngân hàng (TRÁI)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'THÔNG TIN THANH TOÁN',
                          style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        const SizedBox(height: 3),
                        _buildBankDetailRow('Ngân hàng:', widget.invoiceData.shopInfo.bankName, fontSize: 7.5),
                        _buildBankDetailRow('Số TK:', widget.invoiceData.shopInfo.accountNumber, fontSize: 7.5),
                        _buildBankDetailRow('Chủ TK:', widget.invoiceData.shopInfo.accountName, fontSize: 7.5),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5), 

                  // Cột QR Code (PHẢI)
                  SizedBox(
                    width: 70, 
                    height: 70,
                    child: _qrCodeData != null
                        ? Image.memory(_qrCodeData!)
                        : _canGenerateQr
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : const Center(
                                child: Text(
                                  'Không có QR',
                                  style: TextStyle(fontSize: 7, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12), 

          // Footer - Lời cảm ơn
          Text(
            '${widget.invoiceData.shopInfo.name} - Cảm ơn quý khách! Hẹn gặp lại!',
            style: const TextStyle(
              fontSize: 7, 
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            softWrap: true,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List<InvoiceItem> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          // Header bảng (Flex Ratio: 45:10:20:25)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Expanded(flex: 45, child: Text('TÊN S.PHẨM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black))),
                const Expanded(flex: 10, child: Text('SL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black), textAlign: TextAlign.center)),
                const Expanded(flex: 20, child: Text('Đ.GIÁ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black), textAlign: TextAlign.right)),
                const Expanded(flex: 25, child: Text('T.TIỀN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(color: Colors.black, thickness: 0.5, height: 0),
          // Danh sách sản phẩm
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                // Tên sản phẩm
                Expanded(
                  flex: 45, 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 7.5, color: Colors.black),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      if (item.unit.isNotEmpty)
                        Text(
                          '(${item.unit})',
                          style: const TextStyle(fontSize: 6.5, color: Colors.black, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                // Số lượng
                Expanded(
                  flex: 10, 
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 7.5, color: Colors.black),
                  ),
                ),
                // Đơn giá
                Expanded(
                  flex: 20, 
                  child: Text(
                    currency_utils.FormatCurrency.format(item.unitPrice, suffix: ''),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 7.5, color: Colors.black),
                  ),
                ),
                // Thành tiền
                Expanded(
                  flex: 25, 
                  child: Text(
                    currency_utils.FormatCurrency.format(item.totalPrice, suffix: ''),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 7.5, color: Colors.black),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}