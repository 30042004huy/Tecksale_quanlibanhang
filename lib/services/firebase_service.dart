import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final db = FirebaseDatabase.instance.ref();
  final _dbRef = FirebaseDatabase.instance.ref();

  FirebaseService() {
    db.keepSynced(true); // luôn đồng bộ offline/online
  }

  Future<void> luuDonHang(String email, Map<String, dynamic> data) async {
    if (email.isEmpty) {
      print("Lỗi: Email không được để trống");
      throw Exception("Email không được để trống");
    }
    String sanitizedEmail = email.replaceAll('.', '_');
    print("Lưu đơn hàng tại: donhang/$sanitizedEmail");
    try {
      await db.child("donhang").child(sanitizedEmail).set(data);
      print("Lưu đơn hàng thành công");
    } catch (e) {
      print("Lỗi khi lưu đơn hàng: $e");
      rethrow;
    }
  }

  Future<DataSnapshot> layDonHang(String email) async {
    if (email.isEmpty) {
      print("Lỗi: Email không được để trống");
      throw Exception("Email không được để trống");
    }
    String sanitizedEmail = email.replaceAll('.', '_');
    print("Lấy đơn hàng từ: donhang/$sanitizedEmail");
    try {
      final snapshot = await db.child("donhang").child(sanitizedEmail).get();
      if (!snapshot.exists) {
        print("Không tìm thấy dữ liệu tại: donhang/$sanitizedEmail");
      }
      return snapshot;
    } catch (e) {
      print("Lỗi khi lấy đơn hàng: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchAllDataByUID(String uid) async {
    if (uid.isEmpty) {
      print("Lỗi: UID không được để trống");
      throw Exception("UID không được để trống");
    }
    print("Lấy dữ liệu từ: users/$uid");
    try {
      final snapshot = await _dbRef.child('users/$uid').get();
      if (snapshot.exists) {
        print("Dữ liệu tại users/$uid: ${snapshot.value}");
        return Map<String, dynamic>.from(snapshot.value as Map);
      } else {
        print("Không tìm thấy dữ liệu tại users/$uid");
        return null;
      }
    } catch (e) {
      print("Lỗi khi lấy dữ liệu UID: $e");
      return null;
    }
  }
}