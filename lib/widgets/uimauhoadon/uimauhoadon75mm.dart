import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../models/mauhoadon_model.dart';
import '../../../utils/format_currency.dart' as currency_utils;
import '../../../services/vietqr_service.dart';

class UIMauHoaDon75mm extends StatefulWidget {
  final InvoiceData invoiceData;

  const UIMauHoaDon75mm({
    Key? key,
    required this.invoiceData,
  }) : super(key: key);

  @override
  _UIMauHoaDon75mmState createState() => _UIMauHoaDon75mmState();
}

class _UIMauHoaDon75mmState extends State<UIMauHoaDon75mm> {
  Uint8List? _qrCodeData;
  bool _canGenerateQr = false;

  @override
  void initState() {
    super.initState();
    _checkAndGenerateQrCode();
  }
  
  @override
  void didUpdateWidget(covariant UIMauHoaDon75mm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invoiceData.totalPayment != oldWidget.invoiceData.totalPayment) {
      _checkAndGenerateQrCode();
    }
  }

  String _getBankCodeFromName(String bankName) {
    switch (bankName.toLowerCase()) {
      case 'mb bank': return 'MBB';
      case 'vietcombank': return 'VCB';
      case 'vietinbank': return 'ICB';
      case 'techcombank': return 'TCB';
      case 'agribank': return 'VBA';
      case 'sacombank': return 'STB';
      case 'pvcombank': return 'PVB';
      default: return '';
    }
  }

  Future<void> _checkAndGenerateQrCode() async {
    final String bankCode = _getBankCodeFromName(widget.invoiceData.shopInfo.bankName);
    final String accountNumber = widget.invoiceData.shopInfo.accountNumber;
    final String accountName = widget.invoiceData.shopInfo.accountName;
    final double totalAmount = widget.invoiceData.totalPayment;

    _canGenerateQr = bankCode.isNotEmpty && accountNumber.isNotEmpty && accountName.isNotEmpty && totalAmount > 0;

    if (_canGenerateQr) {
      try {
        final qrData = await VietQRService.generateQrCode(
          amount: totalAmount,
        );
        if (mounted) {
          setState(() {
            _qrCodeData = qrData;
          });
        }
      } catch (e) {
        // Handle error
      }
    }
  }

  Widget _buildInfoRow(String label, String value, {int labelFlex = 1, int valueFlex = 3}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.black),
            ),
          ),
          Expanded(
            flex: valueFlex,
            child: Text(
              value,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: Colors.black),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: isTotal ? 10 : 9, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600, color: Colors.black),
          ),
          Text(
            currency_utils.FormatCurrency.format(amount, suffix: 'VNĐ'),
            style: TextStyle(fontSize: isTotal ? 10 : 9, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo(String label, String value, {int labelFlex = 1, int valueFlex = 3}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.black),
            ),
          ),
          Expanded(
            flex: valueFlex,
            child: Text(
              value,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: Colors.black),
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
    const double seventyFiveMmWidth = 283.0;

    return Container(
      width: seventyFiveMmWidth,
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.invoiceData.showShopInfo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 30, 8, 8),
              child: Column(
                children: [
                  Text(
                    widget.invoiceData.shopInfo.name.toUpperCase(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  if (widget.invoiceData.shopInfo.address.isNotEmpty)
                    _buildInfoRow('Địa chỉ:', widget.invoiceData.shopInfo.address, labelFlex: 1, valueFlex: 7),
                  if (widget.invoiceData.shopInfo.phone.isNotEmpty)
                    _buildInfoRow('Điện thoại:', widget.invoiceData.shopInfo.phone, labelFlex: 2, valueFlex: 10),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text('HÓA ĐƠN BÁN HÀNG', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 255, 0, 0)), textAlign: TextAlign.center),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8).copyWith(bottom: 15),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Số HĐ: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black)),
                  Text(widget.invoiceData.invoiceNumber, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.red.shade700)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Ngày: ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black)),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(widget.invoiceData.orderDate ?? DateTime.now()),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.black),
                  ),
                ]),
                
                if (widget.invoiceData.showCustomerInfo && (widget.invoiceData.customerInfo.name.isNotEmpty || widget.invoiceData.customerInfo.phone.isNotEmpty || widget.invoiceData.employeeName?.isNotEmpty == true))
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.invoiceData.customerInfo.name.isNotEmpty)
                          _buildInfoRow('Tên KH:', widget.invoiceData.customerInfo.name, labelFlex: 1, valueFlex: 7),
                        if (widget.invoiceData.customerInfo.phone.isNotEmpty)
                          _buildInfoRow('SĐT:', widget.invoiceData.customerInfo.phone, labelFlex: 1, valueFlex: 10),
                        if (widget.invoiceData.employeeName?.isNotEmpty == true)
                          _buildInfoRow('Nhân viên:', widget.invoiceData.employeeName!, labelFlex: 2, valueFlex: 10),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                  decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('TÊN SP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black))),
                      Expanded(flex: 1, child: Text('SL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('ĐƠN GIÁ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('THÀNH TIỀN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black), textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                ...widget.invoiceData.items.map((item) => Container(
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
                      Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 9, color: Colors.black), softWrap: true, overflow: TextOverflow.visible),
                        if (item.unit.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text('Đơn vị: ${item.unit}', style: const TextStyle(fontSize: 7, color: Colors.black)),
                        ],
                      ])),
                      Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 8, color: Colors.black))),
                      Expanded(flex: 1, child: Text(currency_utils.FormatCurrency.format(item.unitPrice, suffix: ''), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 8, color: Colors.black))),
                      Expanded(flex: 1, child: Text(currency_utils.FormatCurrency.format(item.totalPrice, suffix: ''), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.black))),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _buildTotalRow('Tổng tiền hàng:', widget.invoiceData.subtotal),
                      if (widget.invoiceData.shippingCost > 0)
                        _buildTotalRow('Phí vận chuyển:', widget.invoiceData.shippingCost),
                      if (widget.invoiceData.discount > 0)
                        _buildTotalRow('Giảm giá:', -widget.invoiceData.discount, isDiscount: true),
                      Container(margin: const EdgeInsets.symmetric(vertical: 3), height: 1, color: Colors.black),
                      _buildTotalRow('TỔNG CỘNG:', widget.invoiceData.totalPayment, isTotal: true),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Container(
                  width: double.infinity,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.all(1),
                  child: Text('Bằng chữ: ${widget.invoiceData.totalPaymentInWords}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: Colors.black, fontStyle: FontStyle.italic), softWrap: true, overflow: TextOverflow.visible),
                ),
                if (widget.invoiceData.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(5),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Ghi chú:', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(height: 2),
                      Text(widget.invoiceData.notes, style: const TextStyle(fontSize: 7, color: Colors.black), softWrap: true, overflow: TextOverflow.visible),
                    ]),
                  ),
                ],
                const SizedBox(height: 6),
                
                if (widget.invoiceData.showBankInfo || widget.invoiceData.showQrCode)
                  Container(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        if (widget.invoiceData.showBankInfo)
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 5),
                                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1)),
                                child: const Text('THÔNG TIN THANH TOÁN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                              ),
                              const SizedBox(height: 5),
                              _buildPaymentInfo('Ngân hàng:', widget.invoiceData.shopInfo.bankName),
                              _buildPaymentInfo('Số TK:', widget.invoiceData.shopInfo.accountNumber),
                              _buildPaymentInfo('Chủ TK:', widget.invoiceData.shopInfo.accountName),
                            ],
                          ),
                          
                        if (widget.invoiceData.showBankInfo && widget.invoiceData.showQrCode)
                          const SizedBox(height: 6),

                        if (widget.invoiceData.showQrCode)
                          if (_canGenerateQr && _qrCodeData != null)
                            Container(
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Text('QUÉT MÃ QR ĐỂ THANH TOÁN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                                  const SizedBox(height: 3),
                                  Image.memory(_qrCodeData!, width: 100, height: 100),
                                  const SizedBox(height: 2),
                                  Text('Tổng tiền: ${currency_utils.FormatCurrency.format(widget.invoiceData.totalPayment, suffix: 'VNĐ')}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black)),
                                ],
                              ),
                            )
                          else if (_canGenerateQr && _qrCodeData == null)
                            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                const SizedBox(height: 15),
                
                if (widget.invoiceData.showShopInfo)
                  Container(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${widget.invoiceData.shopInfo.name} - Cảm ơn quý khách!',
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.black),
                      textAlign: TextAlign.center, softWrap: true, overflow: TextOverflow.visible,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}