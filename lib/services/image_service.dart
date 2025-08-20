// image_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

/// Dịch vụ lưu ảnh vào thư viện thiết bị
class ImageService {
  /// Lưu ảnh dạng Uint8List (dữ liệu byte) vào thư mục Pictures
  /// 
  /// [imageBytes]: Dữ liệu byte của ảnh
  /// [fileName]: Tên file (tùy chọn, mặc định là timestamp)
  /// [quality]: Chất lượng ảnh (0-100, mặc định 80) - không sử dụng trong phiên bản này
  /// 
  /// Trả về [Map] chứa thông tin kết quả:
  /// - isSuccess: bool - thành công hay không
  /// - filePath: String? - đường dẫn file đã lưu
  /// - errorMessage: String? - thông báo lỗi nếu có
  static Future<Map<String, dynamic>> saveImageToGallery(
    Uint8List imageBytes, {
    String? fileName,
    int quality = 80,
  }) async {
    try {
      // Kiểm tra quyền ghi file
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return {
          'isSuccess': false,
          'filePath': null,
          'errorMessage': 'Không có quyền ghi file',
        };
      }

      // Lấy thư mục Pictures
      Directory? picturesDir;
      if (Platform.isAndroid) {
        picturesDir = Directory('/storage/emulated/0/Pictures');
        if (!await picturesDir.exists()) {
          picturesDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        picturesDir = await getApplicationDocumentsDirectory();
      } else {
        picturesDir = await getApplicationDocumentsDirectory();
      }

      if (picturesDir == null) {
        return {
          'isSuccess': false,
          'filePath': null,
          'errorMessage': 'Không thể truy cập thư mục Pictures',
        };
      }

      // Tạo tên file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'image_$timestamp';
      final filePath = '${picturesDir.path}/$name.png';

      // Lưu file
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      debugPrint('Đã lưu ảnh vào: $filePath');

      return {
        'isSuccess': true,
        'filePath': filePath,
        'errorMessage': null,
      };
    } catch (e) {
      debugPrint('Lỗi khi lưu ảnh: $e');
      return {
        'isSuccess': false,
        'filePath': null,
        'errorMessage': 'Lỗi: $e',
      };
    }
  }

  /// Lưu ảnh từ đường dẫn file vào thư mục Pictures
  /// 
  /// [filePath]: Đường dẫn đến file ảnh
  /// [fileName]: Tên file (tùy chọn)
  /// [quality]: Chất lượng ảnh (0-100, mặc định 80) - không sử dụng trong phiên bản này
  static Future<Map<String, dynamic>> saveImageFromPath(
    String filePath, {
    String? fileName,
    int quality = 80,
  }) async {
    try {
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        return {
          'isSuccess': false,
          'filePath': null,
          'errorMessage': 'File không tồn tại: $filePath',
        };
      }

      // Đọc dữ liệu từ file gốc
      final imageBytes = await sourceFile.readAsBytes();
      
      // Sử dụng phương thức saveImageToGallery để lưu
      return await saveImageToGallery(
        Uint8List.fromList(imageBytes),
        fileName: fileName,
        quality: quality,
      );
    } catch (e) {
      debugPrint('Lỗi khi lưu ảnh từ đường dẫn: $e');
      return {
        'isSuccess': false,
        'filePath': null,
        'errorMessage': 'Lỗi: $e',
      };
    }
  }

  /// Lưu ảnh từ URL vào thư mục Pictures
  /// 
  /// [imageUrl]: URL của ảnh
  /// [fileName]: Tên file (tùy chọn)
  /// [quality]: Chất lượng ảnh (0-100, mặc định 80) - không sử dụng trong phiên bản này
  static Future<Map<String, dynamic>> saveImageFromUrl(
    String imageUrl, {
    String? fileName,
    int quality = 80,
  }) async {
    try {
      // Tải ảnh từ URL
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode != 200) {
        return {
          'isSuccess': false,
          'filePath': null,
          'errorMessage': 'Không thể tải ảnh từ URL: ${response.statusCode}',
        };
      }

      // Sử dụng phương thức saveImageToGallery để lưu
      return await saveImageToGallery(
        response.bodyBytes,
        fileName: fileName,
        quality: quality,
      );
    } catch (e) {
      debugPrint('Lỗi khi lưu ảnh từ URL: $e');
      return {
        'isSuccess': false,
        'filePath': null,
        'errorMessage': 'Lỗi: $e',
      };
    }
  }

  /// Lưu video vào thư mục Movies
  /// 
  /// [videoPath]: Đường dẫn đến file video
  /// [fileName]: Tên file (tùy chọn)
  static Future<Map<String, dynamic>> saveVideo(
    String videoPath, {
    String? fileName,
  }) async {
    try {
      // Kiểm tra quyền ghi file
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return {
          'isSuccess': false,
          'filePath': null,
          'errorMessage': 'Không có quyền ghi file',
        };
      }

      final sourceFile = File(videoPath);
      if (!await sourceFile.exists()) {
        return {
          'isSuccess': false,
          'filePath': null,
          'errorMessage': 'File video không tồn tại: $videoPath',
        };
      }

      // Lấy thư mục Movies
      Directory? moviesDir;
      if (Platform.isAndroid) {
        moviesDir = Directory('/storage/emulated/0/Movies');
        if (!await moviesDir.exists()) {
          moviesDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        moviesDir = await getApplicationDocumentsDirectory();
      } else {
        moviesDir = await getApplicationDocumentsDirectory();
      }

      if (moviesDir == null) {
        return {
          'isSuccess': false,
          'filePath': null,
          'errorMessage': 'Không thể truy cập thư mục Movies',
        };
      }

      // Tạo tên file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final name = fileName ?? 'video_$timestamp';
      final extension = videoPath.split('.').last;
      final targetPath = '${moviesDir.path}/$name.$extension';

      // Copy file
      await sourceFile.copy(targetPath);

      debugPrint('Đã lưu video vào: $targetPath');

      return {
        'isSuccess': true,
        'filePath': targetPath,
        'errorMessage': null,
      };
    } catch (e) {
      debugPrint('Lỗi khi lưu video: $e');
      return {
        'isSuccess': false,
        'filePath': null,
        'errorMessage': 'Lỗi: $e',
      };
    }
  }

  /// Kiểm tra quyền truy cập storage
  /// 
  /// Trả về [bool] - có quyền hay không
  static Future<bool> hasPermission() async {
    try {
      final status = await Permission.storage.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Lỗi kiểm tra quyền: $e');
      return false;
    }
  }

  /// Yêu cầu quyền truy cập storage
  /// 
  /// Trả về [bool] - có quyền hay không
  static Future<bool> requestPermission() async {
    try {
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Lỗi yêu cầu quyền: $e');
      return false;
    }
  }

  /// Lấy đường dẫn thư mục cache tạm thời
  static Future<String?> getTempDirectoryPath() async {
    try {
      final dir = await getTemporaryDirectory();
      return dir.path;
    } catch (e) {
      debugPrint('Lỗi lấy thư mục cache: $e');
      return null;
    }
  }

  /// Lấy đường dẫn thư mục documents
  static Future<String?> getDocumentsDirectoryPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (e) {
      debugPrint('Lỗi lấy thư mục documents: $e');
      return null;
    }
  }

  /// Lấy đường dẫn thư mục Pictures
  static Future<String?> getPicturesDirectoryPath() async {
    try {
      if (Platform.isAndroid) {
        final picturesDir = Directory('/storage/emulated/0/Pictures');
        if (await picturesDir.exists()) {
          return picturesDir.path;
        }
        final externalDir = await getExternalStorageDirectory();
        return externalDir?.path;
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        return dir.path;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        return dir.path;
      }
    } catch (e) {
      debugPrint('Lỗi lấy thư mục Pictures: $e');
      return null;
    }
  }
}
