// lib/services/persistent_notification_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class NotificationItem {
  final String id;
  final String? title; // ✨ MỚI: Thêm tiêu đề
  final String text;
  final DateTime timestamp;
  final String type;
  final String? orderId;
  bool isRead;

  NotificationItem({
    required this.id,
    this.title, // ✨ MỚI
    required this.text,
    required this.timestamp,
    required this.type,
    this.orderId,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title, // ✨ MỚI
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'type': type,
        'orderId': orderId,
        'isRead': isRead,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] ?? Uuid().v4(),
        title: json['title'] as String?, // ✨ MỚI
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: json['type'] ?? 'general',
        orderId: json['orderId'] as String?,
        isRead: json['isRead'] ?? false,
      );
}

class PersistentNotificationService {
  static const String _notificationsKey = 'persistent_notifications';
  static const int _maxNotifications = 50;
  static const Uuid _uuid = Uuid();

  static final ValueNotifier<List<NotificationItem>> notifications =
      ValueNotifier([]);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNotifications = prefs.getStringList(_notificationsKey) ?? [];

    final loadedNotifications = savedNotifications
        .map((json) {
          try {
            return NotificationItem.fromJson(jsonDecode(json));
          } catch (_) {
            return null;
          }
        })
        .whereType<NotificationItem>()
        .toList();

    loadedNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifications.value = loadedNotifications;
  }

  static Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    List<NotificationItem> notificationsToSave =
        List.from(notifications.value);

    notificationsToSave = notificationsToSave
        .where((item) => now.difference(item.timestamp).inDays < 7)
        .toList();
    if (notificationsToSave.length > _maxNotifications) {
      notificationsToSave = notificationsToSave.sublist(0, _maxNotifications);
    }

    notificationsToSave.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final notificationsJson =
        notificationsToSave.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_notificationsKey, notificationsJson);
  }

  static Future<void> addNotification({
    String? title, // ✨ MỚI: Thêm title
    required String text,
    required String type,
    String? orderId,
  }) async {
    final newNotification = NotificationItem(
      id: _uuid.v4(),
      title: title, // ✨ MỚI
      text: text,
      timestamp: DateTime.now(),
      type: type,
      orderId: orderId,
      isRead: false,
    );

    final currentList = List<NotificationItem>.from(notifications.value);
    currentList.insert(0, newNotification);
    notifications.value = currentList;

    _saveNotifications();
  }

  // ✨ MỚI: HÀM XÓA 1 THÔNG BÁO (cho việc vuốt)
  static Future<void> removeNotification(String id) async {
    final currentList = List<NotificationItem>.from(notifications.value);
    currentList.removeWhere((item) => item.id == id);
    notifications.value = currentList; // Cập nhật ValueNotifier
    await _saveNotifications(); // Lưu thay đổi
  }

  static Future<void> markAsRead(String id) async {
    final currentList = List<NotificationItem>.from(notifications.value);
    final index = currentList.indexWhere((item) => item.id == id);

    if (index != -1 && !currentList[index].isRead) {
      currentList[index].isRead = true;
      notifications.value = currentList;
      _saveNotifications();
    }
  }

  static Future<void> markAllAsRead() async {
    final currentList = List<NotificationItem>.from(notifications.value);
    bool hasUnread = false;

    for (var item in currentList) {
      if (!item.isRead) {
        item.isRead = true;
        hasUnread = true;
      }
    }

    if (hasUnread) {
      notifications.value = currentList;
      await _saveNotifications();
    }
  }

  static Future<void> clearAll() async {
    notifications.value = [];
    _saveNotifications();
  }

  static int getUnreadCount() {
    return notifications.value.where((item) => !item.isRead).length;
  }
}