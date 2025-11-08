// VỊ TRÍ: lib/screens/congno.dart
// THAY THẾ TOÀN BỘ FILE BẰNG ĐOẠN CODE NÀY

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/congno_model.dart';
import '../services/custom_notification_service.dart';
import '../utils/format_currency.dart';
import 'package:flutter/services.dart';

class CongNoScreen extends StatefulWidget {
  const CongNoScreen({Key? key}) : super(key: key);

  @override
  State<CongNoScreen> createState() => _CongNoScreenState();
}

class _CongNoScreenState extends State<CongNoScreen> with SingleTickerProviderStateMixin {
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;

  List<CongNoModel> _allCongNoList = [];
  List<CongNoModel> _filteredConNoList = [];
  List<CongNoModel> _filteredDaThuList = [];

  bool _isLoading = true;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _congNoSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_filterCongNo);
    _setupDataListeners();

      // Khóa màn hình chỉ ở chế độ dọc khi vào trang này
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  }
    

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _congNoSubscription?.cancel();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

    super.dispose();
  }

  /// ✨ NÂNG CẤP: Lắng nghe và tự động đồng bộ hóa dữ liệu
  Future<void> _setupDataListeners() async {
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    
    // 1. Lấy danh sách tất cả ID đơn hàng đang tồn tại một lần
    final donHangSnapshot = await dbRef.child('nguoidung/${user!.uid}/donhang').get();
    final Set<String> existingOrderIds = {};
    if (donHangSnapshot.exists) {
      final donHangData = Map<String, dynamic>.from(donHangSnapshot.value as Map);
      donHangData.forEach((status, orders) {
        final ordersMap = Map<String, dynamic>.from(orders as Map);
        existingOrderIds.addAll(ordersMap.keys);
      });
    }

    // 2. Lắng nghe sự thay đổi của công nợ
    _congNoSubscription = dbRef.child('nguoidung/${user!.uid}/congno').onValue.listen((event) {
      if (mounted) {
        List<CongNoModel> freshCongNoList = [];
        Map<String, dynamic> deletions = {};

        if (event.snapshot.exists) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          data.forEach((key, value) {
            final congNo = CongNoModel.fromMap(value);
            // Kiểm tra xem đơn hàng của công nợ này có còn tồn tại không
            if (existingOrderIds.contains(congNo.orderId)) {
              freshCongNoList.add(congNo);
            } else {
              // Nếu không, đưa vào danh sách chờ xóa
              deletions['/nguoidung/${user!.uid}/congno/${congNo.id}'] = null;
            }
          });
        }
        
        // Thực hiện xóa các công nợ không hợp lệ (nếu có)
        if (deletions.isNotEmpty) {
          dbRef.root.update(deletions);
          print('Đã tự động xóa ${deletions.length} công nợ không hợp lệ.');
        }

        setState(() {
          _allCongNoList = freshCongNoList;
          _filterCongNo();
          _isLoading = false;
        });
      }
    }, onError: (error) {
       if (mounted) setState(() => _isLoading = false);
       print("Lỗi lắng nghe công nợ: $error");
    });
  }

  void _filterCongNo() {
    final query = _searchController.text.toLowerCase();
    
    final tempConNo = _allCongNoList.where((i) => i.status == CongNoStatus.chuaTra).toList()
      ..sort((a, b) => b.debtDate.compareTo(a.debtDate));
    final tempDaThu = _allCongNoList.where((i) => i.status == CongNoStatus.daTra).toList()
      ..sort((a, b) => b.debtDate.compareTo(a.debtDate));

    if (query.isEmpty) {
      _filteredConNoList = tempConNo;
      _filteredDaThuList = tempDaThu;
    } else {
      _filteredConNoList = tempConNo.where((i) => i.customerName.toLowerCase().contains(query) || i.customerPhone.contains(query) || i.orderId.toLowerCase().contains(query)).toList();
      _filteredDaThuList = tempDaThu.where((i) => i.customerName.toLowerCase().contains(query) || i.customerPhone.contains(query) || i.orderId.toLowerCase().contains(query)).toList();
    }
    if(mounted) setState(() {});
  }

  Future<void> _handlePayment(CongNoModel congNo, double paidAmount) {
    if (paidAmount <= 0 || paidAmount > congNo.amount) {
      CustomNotificationService.show(context, message: 'Số tiền không hợp lệ.', textColor: Colors.red);
      return Future.value();
    }

    final remainingAmount = congNo.amount - paidAmount;
    final paymentNote = 'Đã trả: ${FormatCurrency.format(paidAmount)} ngày ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';
    final newNotes = congNo.notes.isEmpty ? paymentNote : '${congNo.notes}\n$paymentNote';

    final Map<String, dynamic> updates = {};
    if (remainingAmount > 0.001) {
      updates['amount'] = remainingAmount;
      updates['notes'] = newNotes;
    } else {
      updates['status'] = CongNoStatus.daTra.toString().split('.').last;
      updates['notes'] = newNotes;
    }
    
    return dbRef.child('nguoidung/${user!.uid}/congno/${congNo.id}').update(updates).then((_) {
      CustomNotificationService.show(context, message: 'Đã cập nhật thanh toán thành công!');
    });
  }

  /// ✨ POPUP THANH TOÁN CHỐNG TRÀN GIAO DIỆN
  Future<void> _showPaymentDialog(CongNoModel congNo) async {
    final amountController = TextEditingController(text: congNo.amount.toStringAsFixed(0));
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String amountInWords = FormatCurrency.numberToWords(double.tryParse(amountController.text) ?? 0);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                width: MediaQuery.of(context).size.width * 0.95, // Rộng hơn một chút
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // PHẦN NỘI DUNG CÓ THỂ CUỘN
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Thanh toán công nợ', style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade100)
                              ),
                              child: Column(
                                children: [
                                  _buildDialogInfoRow(Icons.receipt, 'Số HĐ: ${congNo.orderId}'),
                                  const Divider(height: 16),
                                  _buildDialogInfoRow(Icons.person, congNo.customerName),
                                  const SizedBox(height: 8),
                                  _buildDialogInfoRow(Icons.phone, congNo.customerPhone),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.roboto(fontSize: 16, color: Colors.black87),
                                children: [
                                  const TextSpan(text: 'Số nợ hiện tại: '),
                                  TextSpan(
                                    text: FormatCurrency.format(congNo.amount),
                                    style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 17),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Số tiền thanh toán',
                                // Luôn hiển thị viền
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(8))
                                ),
                                // Viền khi không được chọn
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                                  borderSide: BorderSide(color: Colors.grey.shade400),
                                ),
                                // Viền khi được chọn (nhấn vào)
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                                ),
                              ),
                              autofocus: true,
                              onChanged: (value) {
                                double amount = double.tryParse(value) ?? 0;
                                if (amount > congNo.amount) {
                                  amount = congNo.amount;
                                  amountController.text = amount.toStringAsFixed(0);
                                  amountController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: amountController.text.length),
                                  );
                                }
                                setDialogState(() {});
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              amountInWords,
                              style: GoogleFonts.roboto(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // PHẦN NÚT BẤM CỐ ĐỊNH Ở DƯỚI CÙNG
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('HỦY', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                           icon: const Icon(Icons.check_circle, size: 20),
                           label: Text('XÁC NHẬN', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                           style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                           ),
                          onPressed: () {
                            final amount = double.tryParse(amountController.text);
                            if (amount != null && amount > 0) {
                              Navigator.of(context).pop();
                              _handlePayment(congNo, amount);
                            } else {
                              CustomNotificationService.show(context, message: 'Số tiền thanh toán phải lớn hơn 0', textColor: Colors.red);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Công nợ', style: GoogleFonts.roboto()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.roboto(fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.roboto(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          tabs: const [
            Tab(text: 'CÒN NỢ'),
            Tab(text: 'ĐÃ THU'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ✨ Ô TÌM KIẾM ĐƯỢC ĐÓNG KHUNG
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, SĐT, số hóa đơn...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: GoogleFonts.roboto(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCongNoListView(_filteredConNoList, isDebt: true),
                      _buildCongNoListView(_filteredDaThuList, isDebt: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
  
  // Các hàm build còn lại không thay đổi
  // ...
  Widget _buildCongNoListView(List<CongNoModel> list, {required bool isDebt}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isNotEmpty
              ? 'Không tìm thấy kết quả.'
              : (isDebt ? 'Không có công nợ nào.' : 'Chưa có khoản thu nào.'),
          style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      itemCount: list.length,
      itemBuilder: (context, index) => _buildCongNoCard(list[index], isDebt: isDebt),
    );
  }

  Widget _buildCongNoCard(CongNoModel congNo, {required bool isDebt}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDebt ? Colors.orange.shade200 : Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    congNo.customerName,
                    style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('HĐ: ${congNo.orderId}', style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey.shade700)),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: congNo.orderId));
                    CustomNotificationService.show(context, message: 'Đã sao chép số hóa đơn!');
                  },
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(left: 8),
                ),
              ],
            ),
            const Divider(height: 15),
            _buildInfoRow(Icons.phone, congNo.customerPhone),
            _buildInfoRow(Icons.calendar_today, DateFormat('dd/MM/yyyy').format(congNo.debtDate)),
            if (congNo.notes.isNotEmpty)
              _buildInfoRow(Icons.notes, congNo.notes, isNote: true),
            const SizedBox(height: 12),
// THAY THẾ TOÀN BỘ Row CŨ BẰNG ĐOẠN NÀY

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end, // Căn chỉnh các mục theo phía dưới cho đẹp hơn
              children: [
                // 1. Bọc cột chứa số tiền trong Expanded để nó tự co dãn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isDebt ? 'Số tiền nợ' : 'Số tiền gốc', style: GoogleFonts.roboto(fontSize: 14, color: Colors.black54)),
                      // 2. Bọc Text số tiền trong FittedBox để nó tự thu nhỏ
                      FittedBox(
                        fit: BoxFit.scaleDown, // Chỉ thu nhỏ, không phóng to
                        alignment: Alignment.centerLeft, // Căn chữ về bên trái
                        child: Text(
                          FormatCurrency.format(congNo.amount),
                          style: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.bold, color: isDebt ? Colors.red.shade700 : Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                // Thêm một khoảng cách nhỏ để không bị dính vào nút
                const SizedBox(width: 16), 
                // Nút "Thanh toán" giữ nguyên
                if (isDebt)
                  ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(congNo),
                    icon: const Icon(Icons.payment, size: 20),
                    label: Text('Thanh toán', style: GoogleFonts.roboto()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isNote = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: isNote ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.roboto(fontSize: 14, fontStyle: isNote ? FontStyle.italic : FontStyle.normal))),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(IconData icon, String text) {
     return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade800),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.roboto(fontSize: 15))),
      ],
    );
  }
}