import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Thêm import này
import 'package:shared_preferences/shared_preferences.dart'; // Thêm import này

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref().child('nguoidung'); // Khai báo reference tới node users

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Thay đổi kiểu trả về thành Future<UserCredential> để nhất quán
  Future<UserCredential> signIn(String email, String password) async {
    try {
      print("AuthService: Bắt đầu đăng nhập với email: $email");

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user == null) {
        print('AuthService: Đăng nhập thành công nhưng user null');
        throw Exception('Đăng nhập thất bại. Vui lòng thử lại.');
      }

      print("AuthService: Đăng nhập thành công với user: ${user.email}");
      return userCredential; // Trả về UserCredential
    } on FirebaseAuthException catch (e) {
      print('AuthService: Lỗi đăng nhập Firebase: ${e.code} - ${e.message}');
      // Ném lại lỗi để UI có thể bắt và hiển thị thông báo cụ thể
      throw e;
    } catch (e) {
      print('AuthService: Lỗi không xác định: $e');
      rethrow;
    }
  }

  // Phương thức để lấy trạng thái isEnabled từ Realtime Database
  Future<bool?> isUserEnabled(String uid) async {
    try {
      final DataSnapshot snapshot = await _usersRef.child(uid).get();
      if (snapshot.exists && snapshot.value is Map) {
        final userData = snapshot.value as Map<dynamic, dynamic>;
        return userData['isEnabled'] as bool?; // Trả về null nếu trường không tồn tại
      }
      return null; // Không tìm thấy thông tin người dùng trong DB
    } catch (e) {
      print("AuthService: Lỗi khi kiểm tra trạng thái isEnabled: $e");
      return null;
    }
  }

  // Phương thức đăng xuất và xóa trạng thái ghi nhớ
  Future<void> signOut() async {
    print("AuthService: Đang thực hiện đăng xuất...");
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rememberMe');
    await prefs.remove('emailUser');
    print("AuthService: Đăng xuất hoàn tất và đã xóa dữ liệu ghi nhớ.");
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print("AuthService: Đã gửi email đặt lại mật khẩu đến: $email");
    } on FirebaseAuthException catch (e) {
      print("AuthService: Lỗi gửi email đặt lại mật khẩu: ${e.code} - ${e.message}");
      throw e;
    } catch (e) {
      print("AuthService: Lỗi không xác định khi gửi email đặt lại: $e");
      rethrow;
    }
  }
}