import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../models/mauhoadon_model.dart'; // Import các model hóa đơn
import '../../../services/vietqr_service.dart'; // Import dịch vụ VietQR

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
    // Generate QR code once during initialization
    _generateQrCode();
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

  // Hàm tiện ích để xây dựng các hàng thông tin
  Widget _buildInfoRow(String label, String value,
      {double fontSize = 7,
      FontWeight fontWeight = FontWeight.w500,
      Color? valueColor,
      int labelFlex = 2,
      int valueFlex = 5}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.1), // Giảm padding tối đa
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
                color: valueColor ?? Colors.black, // Sử dụng màu tùy chỉnh nếu có
              ),
              maxLines: 2, // Giữ maxLines để xử lý trường hợp quá dài
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Hàm tiện ích để xây dựng các phần thông tin có tiêu đề
  Widget _buildInfoSection(String title, List<Widget> children, {bool isCentered = false}) {
    return Column(
      crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start, // Căn giữa nếu được chỉ định
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4), // Giảm padding
          decoration: BoxDecoration(
            border: Border.all(color: const Color.fromARGB(255, 66, 66, 66), width: 0.5),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 7, // Giảm font tiêu đề
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 0), // Đã giảm khoảng cách ở đây
        ...children,
      ],
    );
  }

  // Hàm tiện ích để xây dựng hàng tổng tiền
  Widget _buildTotalRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1), // Giảm padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 10 : 8, // Giảm font tổng tiền
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            FormatCurrency.formatCurrency(amount), // Sử dụng FormatCurrency từ model
            style: TextStyle(
              fontSize: isTotal ? 10 : 8, // Giảm font tổng tiền
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? Colors.red.shade700 : Colors.black, // Tổng tiền màu đỏ
            ),
          ),
        ],
      ),
    );
  }

  // Hàm tiện ích để xây dựng thông tin thanh toán
  Widget _buildPaymentInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.2), // Giảm padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2, // Flex cho nhãn
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 8, // Giảm font
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 5, // Flex cho giá trị
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 8, // Giảm font
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
    // Kích thước A5 theo points (1 inch = 72 points)
    // A5: 148mm x 210mm
    // 1mm = 72/25.4 points
    // Width: 148 * (72 / 25.4) = 419.52 points
    // Height: 210 * (72 / 25.4) = 595.28 points
    const double a5Width = 419.52;
    const double a5Height = 595.28;

    return Container(
      width: a5Width,
      height: a5Height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8), // Giảm padding tổng thể cho nội dung
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Column(
              children: [
                Text(
                  widget.invoiceData.shopInfo.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20, // Giảm kích thước
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 1), // Giảm khoảng cách
                Text(
                  'HÓA ĐƠN BÁN HÀNG',
                  style: const TextStyle(
                    fontSize: 15, // Giảm kích thước
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 196, 0, 0),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15), // Giảm khoảng cách
              ],
            ),

            // Shop and Customer Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInfoSection('THÔNG TIN CỬA HÀNG', [
                    _buildInfoRow('Điện thoại:', widget.invoiceData.shopInfo.phone, labelFlex: 2, valueFlex: 7),
                    _buildInfoRow('Địa chỉ:', widget.invoiceData.shopInfo.address, labelFlex: 2, valueFlex: 10),
                  ]),
                ),
                const SizedBox(width: 6), // Giảm khoảng cách
                Expanded(
                  flex: 1,
                  child: _buildInfoSection('THÔNG TIN KHÁCH HÀNG', [
                    _buildInfoRow('Tên KH:', widget.invoiceData.customerInfo.name, labelFlex: 3, valueFlex: 7),
                    _buildInfoRow('SĐT:', widget.invoiceData.customerInfo.phone, labelFlex: 3, valueFlex: 10),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 15), // Giảm khoảng cách

            // Invoice Info (moved and centered)
            Align(
              alignment: Alignment.center,
              child: _buildInfoSection('THÔNG TIN HÓA ĐƠN', [
                const SizedBox(height: 4), // Tăng khoảng cách ở đây
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Căn giữa nội dung trong hàng
                  children: [
                    Text(
                      'Số HĐ: ',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      widget.invoiceData.invoiceNumber,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: Colors.red.shade700, // Số HĐ màu đỏ
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center, // Căn giữa nội dung trong hàng
                  children: [
                    Text(
                      'Ngày: ',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ], isCentered: true),
            ),
            const SizedBox(height: 15), // Giảm khoảng cách

            // Product Items Table
            Expanded(
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), // Giảm padding
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 13, child: Text('TÊN SẢN PHẨM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black))),
                        VerticalDivider(color: Colors.black, thickness: 0.5), // Kẻ dọc
                        Expanded(flex: 3, child: Text('SL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), textAlign: TextAlign.center)),
                        VerticalDivider(color: Colors.black, thickness: 0.5), // Kẻ dọc
                        Expanded(flex: 4, child: Text('ĐƠN VỊ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), textAlign: TextAlign.center)),
                        VerticalDivider(color: Colors.black, thickness: 0.5), // Kẻ dọc
                        Expanded(flex: 6, child: Text('ĐƠN GIÁ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), textAlign: TextAlign.right)),
                        VerticalDivider(color: Colors.black, thickness: 0.5), // Kẻ dọc
                        Expanded(flex: 7, child: Text('THÀNH TIỀN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  // Table Rows
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.invoiceData.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.invoiceData.items[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), // Giảm padding
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.black, width: 0.5),
                              left: BorderSide(color: Colors.black, width: 1),
                              right: BorderSide(color: Colors.black, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 13,
                                child: Text(
                                  item.name,
                                  style: const TextStyle(fontSize: 6, color: Colors.black), // Giảm font
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              VerticalDivider(color: Colors.grey.shade300, thickness: 0.5), // Kẻ dọc mờ
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '${item.quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 6, color: Colors.black), // Giảm font
                                ),
                              ),
                              VerticalDivider(color: Colors.grey.shade300, thickness: 0.5), // Kẻ dọc mờ
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.unit,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 6, color: Colors.black), // Giảm font
                                ),
                              ),
                              VerticalDivider(color: Colors.grey.shade300, thickness: 0.5), // Kẻ dọc mờ
                              Expanded(
                                flex: 6,
                                child: Text(
                                  FormatCurrency.formatCurrency(item.unitPrice), // Bỏ VNĐ
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 6, color: Colors.black), // Giảm font
                                ),
                              ),
                              VerticalDivider(color: Colors.grey.shade300, thickness: 0.5), // Kẻ dọc mờ
                              Expanded(
                                flex: 7,
                                child: Text(
                                  FormatCurrency.formatCurrency(item.totalPrice), // Bỏ VNĐ
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 6, color: Colors.black), // Giảm font
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6), // Giảm khoảng cách

            // Summary and Payment Info
            Column(
              children: [
                // Total Summary
                Container(
                  padding: const EdgeInsets.all(6), // Giảm padding
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.black, width: 0.5)),
                  ),
                  child: Column(
                    children: [
                      _buildTotalRow('Tổng tiền hàng:', widget.invoiceData.subtotal),
                      if (widget.invoiceData.shippingCost > 0)
                        _buildTotalRow('Phí vận chuyển:', widget.invoiceData.shippingCost),
                      if (widget.invoiceData.discount > 0)
                        _buildTotalRow('Giảm giá:', -widget.invoiceData.discount, isDiscount: true),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 2), // Giảm margin
                        height: 0.5, // Giảm độ dày đường kẻ
                        color: Colors.black,
                      ),
                      _buildTotalRow(
                        'TỔNG CỘNG:',
                        widget.invoiceData.totalPayment,
                        isTotal: true,
                      ),
                      const SizedBox(height: 1), // Giảm khoảng cách
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Bằng chữ: ${widget.invoiceData.totalPaymentInWords}',
                          style: const TextStyle(fontSize: 7, fontStyle: FontStyle.italic, color: Colors.black), // Giảm font
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6), // Giảm khoảng cách

                // Notes
                if (widget.invoiceData.notes.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6), // Giảm padding
                    decoration: BoxDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ghi chú:',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black), // Giảm font
                        ),
                        const SizedBox(height: 2), // Giảm khoảng cách
                        Text(
                          widget.invoiceData.notes,
                          style: const TextStyle(fontSize: 7, color: Colors.black), // Giảm font
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6), // Giảm khoảng cách
                ],

                // Payment Info & QR Code
                Container(
                  padding: const EdgeInsets.all(6), // Giảm padding
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.black, width: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'THÔNG TIN THANH TOÁN',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black), // Giảm font
                      ),
                      const SizedBox(height: 4), // Giảm khoảng cách
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const SizedBox(width: 1), // Giảm khoảng cách
                          Expanded(
                            flex: 1,
                            child: _qrCodeData == null
                                ? Column(
                                    children: [
                                      const Center(
                                        child: SizedBox(
                                          width: 35,
                                          height: 35,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      const Text(
                                        'QUÉT MÃ QR',
                                        style: TextStyle(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                      const SizedBox(height: 1),
                                      Image.memory(
                                        _qrCodeData!,
                                        width: 85,
                                        height: 85,
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6), // Giảm khoảng cách

                // Footer - Thank You
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