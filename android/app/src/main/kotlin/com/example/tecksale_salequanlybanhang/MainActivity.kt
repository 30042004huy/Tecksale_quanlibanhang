// Tệp: android/app/src/main/kotlin/com/example/tecksale_quanlybanhang/MainActivity.kt

package com.example.tecksale_quanlybanhang // Giữ nguyên package name này

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

// Import các thư viện cần thiết
import android.os.Build
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.net.Uri
import android.media.AudioAttributes

class MainActivity: FlutterActivity() {

    // Ghi đè hàm này để cấu hình kênh
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Bắt đầu từ Android 8.0 (API 26), bạn phải đăng ký notification channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            
            // 1. ID channel (PHẢI KHỚP VỚI TỆP MANIFEST.XML)
            val channelId = "high_importance_channel"

            // 2. Tên channel (hiển thị trong cài đặt điện thoại)
            val channelName = "Thông báo đơn hàng" 

            // 3. Đường dẫn tới file âm thanh (trong res/raw/)
            // Đảm bảo tên file là 'notification_sound' (KHÔNG GỒM ĐUÔI .mp3)
            val soundUri = Uri.parse(
                "android.resource://" + packageName + "/raw/notification_sound"
            )

            // 4. Thiết lập thuộc tính âm thanh
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            // 5. Tạo đối tượng NotificationChannel
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH // Giữ độ ưu tiên cao
            ).apply {
                description = "Kênh thông báo cho đơn hàng mới"
                enableLights(true)
                enableVibration(true)
                // GÁN ÂM THANH TÙY CHỈNH VÀO KÊNH NÀY
                setSound(soundUri, audioAttributes)
            }

            // 6. Đăng ký kênh với hệ thống
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}