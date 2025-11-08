// main.dart (CẬP NHẬT ĐỂ TỐI ƯU HÓA - KHÔNG CÓ MÀN HÌNH TRẮNG)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'screens/splash.dart';
import 'services/persistent_notification_service.dart';

/// Global local notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _showLocalNotification(message);
  await _addToInAppNotifications(message);
}

/// Show a local notification (foreground / background)
Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails android = AndroidNotificationDetails(
    'high_importance_channel',
    'Thông báo quan trọng',
    channelDescription: 'Kênh cho đơn hàng mới',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );
  const NotificationDetails platform = NotificationDetails(android: android);

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.data['title'] ?? message.notification?.title ?? 'TeckSale',
    message.data['body'] ?? message.notification?.body ?? 'Có thông báo mới',
    platform,
    payload: jsonEncode(message.data),
  );
}

/// Add notification to in-app list (persistent)
Future<void> _addToInAppNotifications(RemoteMessage message) async {
  
  // ✨ SỬA LỖI:
  // 1. Ưu tiên lấy 'body' từ message.data (cho đơn hàng web)
  // 2. Nếu không có, lấy 'body' từ message.notification (cho tin nhắn từ Console)
  // 3. Nếu cả hai không có, dùng text mặc định
  final String notificationTitle = message.data['title'] ?? 
                                   message.notification?.title ?? 
                                   'Thông báo'; // Tiêu đề
  
  final String notificationText = message.data['body'] ?? 
                                  message.notification?.body ?? 
                                  'Bạn có thông báo mới.'; // Nội dung

  await PersistentNotificationService.addNotification(
    title: notificationTitle, // <-- GỬI TIÊU ĐỀ
    text: notificationText, // <-- GỬI NỘI DUNG
    type: message.data['type'] ?? 'general', 
    orderId: message.data['orderId'],
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialise Firebase (giữ nguyên await vì cần thiết, nhưng nó nhanh ~100-200ms)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Chạy app NGAY LẬP TỨC mà không await các phần khác
  runApp(const MyApp());

  // 3. Chạy các init khác async trong background (không block UI)
  _initializeNotificationsInBackground();
}

/// Hàm init notifications async (chạy ngầm sau khi app start)
Future<void> _initializeNotificationsInBackground() async {
  try {
    // 2. Initialise local notifications
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Optional: handle tap on notification
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          debugPrint('Notification tapped: $data');
        }
      },
    );

    // 3. Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Thông báo quan trọng',
      description: 'Kênh dùng cho thông báo quan trọng',
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Request permission (iOS + Android 13+)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5. Get and save FCM token (only when user is logged in)
    final token = await messaging.getToken();
    final user = FirebaseAuth.instance.currentUser;
    if (token != null && user != null) {
      final ref = FirebaseDatabase.instance.ref();
      await ref.child('nguoidung/${user.uid}/fcmToken').set(token);
      debugPrint('FCM Token saved: $token');
    }

    // 6. Foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
      _addToInAppNotifications(message);
    });

    // 7. Background message handling (đã set ở top-level)

    // 8. (Optional) Handle when app is opened from a terminated state via notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _addToInAppNotifications(initialMessage);
    }
  } catch (e) {
    debugPrint('Error initializing notifications in background: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeckSale',
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 30, 154, 255),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color.fromARGB(255, 30, 154, 255),
          secondary: const Color.fromARGB(255, 30, 154, 255),
        ),
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: Colors.black,
              displayColor: Colors.black,
            ),
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}