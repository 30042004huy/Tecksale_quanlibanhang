// models/congno_model.dart

enum CongNoStatus { chuaTra, daTra }

class CongNoModel {
  final String id;
  final String orderId;
  final String customerName;
  final String customerPhone;
  final double amount;
  final DateTime debtDate;
  final String notes; // ✨ 1. KHAI BÁO TRƯỜNG 'notes'
  CongNoStatus status;

  CongNoModel({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    required this.debtDate,
    this.status = CongNoStatus.chuaTra,
    this.notes = '', // <-- THÊM DÒNG NÀY (thêm dấu phẩy ở dòng trên nếu cần)
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'amount': amount,
      'debtDate': debtDate.toIso8601String(),
      'status': status.toString().split('.').last,
      'notes': notes, // ✨ 3. THÊM 'notes' VÀO HÀM toMap
    };
  }

  factory CongNoModel.fromMap(Map<dynamic, dynamic> map) {
    return CongNoModel(
      id: map['id'] ?? '',
      orderId: map['orderId'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      debtDate: DateTime.tryParse(map['debtDate'] ?? '') ?? DateTime.now(),
      status: (map['status'] == 'daTra') ? CongNoStatus.daTra : CongNoStatus.chuaTra,
      notes: map['notes'] ?? '', // ✨ 4. ĐỌC 'notes' TỪ FIREBASE
    );
  }
}