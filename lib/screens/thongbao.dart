import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';

class ThongBaoScreen extends StatefulWidget {
  const ThongBaoScreen({super.key});

  @override
  State<ThongBaoScreen> createState() => _ThongBaoScreenState();
}

class _ThongBaoScreenState extends State<ThongBaoScreen> with SingleTickerProviderStateMixin {
  final ValueNotifier<List<NotificationItem>> _notifications = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  late AnimationController _animationController;
  static const String _lastUpdateKey = 'last_notification_update';
  static const String _notificationsKey = 'notifications';
  static const int _maxNotifications = 20;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.microtask(() async {
      try {
        await _loadNotifications();
        await _checkDailyUpdate();
      } catch (e) {
        _showSnackBar('Lỗi tải thông báo: $e');
      } finally {
        _isLoading.value = false;
      }
    });
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNotifications = prefs.getStringList(_notificationsKey) ?? [];
    final now = DateTime.now();
    final loadedNotifications = savedNotifications
        .map((json) {
          try {
            return NotificationItem.fromJson(jsonDecode(json));
          } catch (_) {
            return null;
          }
        })
        .whereType<NotificationItem>()
        .where((item) => now.difference(item.timestamp).inDays < 7)
        .toList();
    
    _notifications.value = loadedNotifications;
    await _saveNotifications();
  }

  Future<void> _checkDailyUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getString(_lastUpdateKey);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastUpdate == null || lastUpdate != today) {
      await _addDailyNotification();
      await prefs.setString(_lastUpdateKey, today);
    }
  }

  Future<void> _addDailyNotification() async {
    final now = DateTime.now();
    const messages = [
      'Hôm nay là ngày tuyệt vời để tạo đơn hàng mới trên TeckSale! 🚀',
      'Khám phá tính năng quản lý kho mới để tối ưu hóa kinh doanh của bạn.',
      'Cần hỗ trợ? Liên hệ qua email Tecksale04@gmail.com hoặc Zalo!',
      'TeckSale đang miễn phí! Tận dụng ngay để quản lý bán hàng hiệu quả.',
    ];
    final randomMessage = messages[Random().nextInt(messages.length)];
    final newNotifications = List<NotificationItem>.from(_notifications.value)
      ..add(NotificationItem(text: randomMessage, timestamp: now));
    _notifications.value = newNotifications;
    await _saveNotifications();
  }

  Future<void> _addWelcomeNotification() async {
    final newNotifications = List<NotificationItem>.from(_notifications.value)
      ..add(NotificationItem(
        text: 'Chào mừng bạn đến với TeckSale! Tạo đơn hàng ngay để khám phá các tính năng tuyệt vời.',
        timestamp: DateTime.now(),
      ));
    _notifications.value = newNotifications;
    await _saveNotifications();
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final validNotifications = _notifications.value
          .where((item) => now.difference(item.timestamp).inDays < 7)
          .toList();
      if (validNotifications.length > _maxNotifications) {
        validNotifications.removeRange(0, validNotifications.length - _maxNotifications);
      }
      final notificationsJson = validNotifications.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_notificationsKey, notificationsJson);
      _notifications.value = validNotifications;
    } catch (e) {
      _showSnackBar('Lỗi lưu thông báo: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Xóa tất cả thông báo?'),
        content: const Text('Bạn có chắc muốn xóa toàn bộ thông báo? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: Theme.of(context).primaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _notifications.value = [];
      await _saveNotifications();
      _showSnackBar('Đã xóa tất cả thông báo.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notifications.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoading,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return Center(
              child: RotationTransition(
                turns: Tween(begin: 0.0, end: 1.0).animate(_animationController),
                child: Icon(Icons.notifications, size: 48, color: Theme.of(context).primaryColor),
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 100,
                floating: true,
                pinned: true,
                title: const Text(
                  'Thông Báo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                ),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  ValueListenableBuilder<List<NotificationItem>>(
                    valueListenable: _notifications,
                    builder: (context, notifications, _) {
                      if (notifications.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(Icons.delete_sweep, size: 24),
                        onPressed: _clearAllNotifications,
                        tooltip: 'Xóa tất cả',
                      );
                    },
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                sliver: ValueListenableBuilder<List<NotificationItem>>(
                  valueListenable: _notifications,
                  builder: (context, notifications, _) {
                    if (notifications.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Không có thông báo nào',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () async {
                                _isLoading.value = true;
                                await _addWelcomeNotification();
                                _isLoading.value = false;
                              },
                              child: Text(
                                'Làm mới',
                                style: TextStyle(fontSize: 14, color: Theme.of(context).primaryColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final notification = notifications[index];
                          return AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Dismissible(
                              key: ValueKey(notification.timestamp),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    title: const Text('Xóa thông báo?'),
                                    content: const Text('Bạn có chắc muốn xóa thông báo này?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text('Hủy', style: TextStyle(color: Theme.of(context).primaryColor)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) {
                                final newNotifications = List<NotificationItem>.from(notifications)
                                  ..removeAt(index);
                                _notifications.value = newNotifications;
                                _saveNotifications();
                                _showSnackBar('Đã xóa thông báo.');
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                    child: Icon(Icons.notifications, size: 20, color: Theme.of(context).primaryColor),
                                  ),
                                  title: Text(
                                    notification.text,
                                    style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      DateFormat('dd/MM/yyyy HH:mm').format(notification.timestamp),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: notifications.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NotificationItem {
  final String text;
  final DateTime timestamp;

  const NotificationItem({
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}