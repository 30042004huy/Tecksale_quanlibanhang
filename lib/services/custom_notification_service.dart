// VỊ TRÍ: lib/services/custom_notification_service.dart
// THAY THẾ TOÀN BỘ FILE BẰNG ĐOẠN CODE NÀY

import 'package:flutter/material.dart';
import 'dart:async';

/// Dịch vụ quản lý việc hiển thị thông báo tùy chỉnh từ trên xuống.
/// Đảm bảo chỉ có một thông báo được hiển thị tại một thời điểm.
class CustomNotificationService {
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;
  static Timer? _timer; // Thêm biến timer để có thể hủy

  /// Hiển thị một thông báo.
  ///
  /// [context]: BuildContext của màn hình hiện tại.
  /// [message]: Nội dung thông báo.
  /// [backgroundColor]: Màu nền của thông báo.
  /// [textColor]: Màu chữ của thông báo.
  /// [duration]: Thời gian hiển thị.
  static void show(
    BuildContext context, {
    required String message,
    Color backgroundColor = const Color.fromRGBO(255, 255, 255, 0.95), // Trắng mờ hơn một chút
    Color textColor = Colors.green, // Chữ xanh lá
    Duration duration = const Duration(milliseconds: 2000), // Kéo dài thời gian hiển thị một chút
  }) {
    // Nếu có thông báo cũ, hãy hủy nó ngay lập tức trước khi hiển thị thông báo mới
    if (_isVisible) {
      _hide(immediately: true);
    }

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).viewPadding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          // ✨ BỌC BẰNG GestureDetector ĐỂ LẮNG NGHE SỰ KIỆN VUỐT
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              // Kiểm tra xem người dùng có vuốt lên không (vận tốc âm)
              if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
                _hide();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _isVisible = true;
    overlay.insert(_overlayEntry!);

    // Hẹn giờ để tự động ẩn thông báo
    _timer = Timer(duration, () {
      _hide();
    });
  }

  /// Ẩn thông báo hiện tại (nếu có).
  static void _hide({bool immediately = false}) {
    // Hủy timer để tránh lỗi nếu người dùng vuốt lên trước khi hết giờ
    _timer?.cancel();
    
    if (_overlayEntry != null) {
      // Nếu là `immediately`, xóa ngay lập tức
      // Trong tương lai, có thể thêm hiệu ứng trượt lên ở đây nếu `immediately` là false
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isVisible = false;
    }
  }
}