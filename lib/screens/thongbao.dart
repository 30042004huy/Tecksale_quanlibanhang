// lib/screens/thongbao.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts
import 'package:intl/intl.dart';
import 'package:tecksale_quanlybanhang/services/persistent_notification_service.dart';
import 'website_orders_screen.dart';

class ThongBaoScreen extends StatefulWidget {
  const ThongBaoScreen({super.key});

  @override
  State<ThongBaoScreen> createState() => _ThongBaoScreenState();
}

class _ThongBaoScreenState extends State<ThongBaoScreen> {
  Future<void> _handleRefresh() async {
    // Chỉ cần build lại, ValueListenable đã giữ data
    setState(() {});
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Xóa tất cả thông báo?',
            style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        content: const Text(
            'Bạn có chắc muốn xóa toàn bộ thông báo? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy',
                style: GoogleFonts.roboto(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Xóa',
                style: GoogleFonts.roboto(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PersistentNotificationService.clearAll();
      _showSnackBar('Đã xóa tất cả thông báo.');
    }
  }

  Future<void> _markAllAsRead() async {
    await PersistentNotificationService.markAllAsRead();
    _showSnackBar('Đã đánh dấu tất cả là đã đọc.');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _onNotificationTapped(NotificationItem notification) {
    PersistentNotificationService.markAsRead(notification.id);

    if (notification.type == 'new_web_order') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const WebsiteOrdersScreen(initialTab: 0),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey[100], // Nền xám nhạt
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              floating: true,
              pinned: true,
              title: Text(
                'Thông Báo',
                style: GoogleFonts.quicksand(
                    fontWeight: FontWeight.bold, fontSize: 22),
              ),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                ValueListenableBuilder<List<NotificationItem>>(
                  valueListenable: PersistentNotificationService.notifications,
                  builder: (context, notifications, _) {
                    final hasUnread = notifications.any((n) => !n.isRead);
                    if (!hasUnread) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.done_all, size: 24),
                      onPressed: _markAllAsRead,
                      tooltip: 'Đánh dấu tất cả là đã đọc',
                    );
                  },
                ),
                ValueListenableBuilder<List<NotificationItem>>(
                  valueListenable: PersistentNotificationService.notifications,
                  builder: (context, notifications, _) {
                    if (notifications.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, size: 24),
                      onPressed: _clearAllNotifications,
                      tooltip: 'Xóa tất cả',
                    );
                  },
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: ValueListenableBuilder<List<NotificationItem>>(
                valueListenable: PersistentNotificationService.notifications,
                builder: (context, notifications, _) {
                  // Widget khi không có thông báo
                  if (notifications.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Không có thông báo nào',
                            style: GoogleFonts.roboto(
                                fontSize: 17,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _handleRefresh,
                            child: Text(
                              'Tải lại',
                              style: GoogleFonts.roboto(
                                  fontSize: 15,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  // Danh sách thông báo
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final notification = notifications[index];
                        final bool isRead = notification.isRead;
                        final bool hasTitle = notification.title != null &&
                            notification.title!.isNotEmpty;

                        // ✨ 1. DÙNG DISMISSIBLE ĐỂ VUỐT XÓA
                        return Dismissible(
                          key: Key(notification.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) {
                            // GỌI HÀM XÓA MỚI
                            PersistentNotificationService.removeNotification(
                                notification.id);
                            _showSnackBar('Đã xóa thông báo.');
                          },
                          // Giao diện nền khi vuốt
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.centerRight,
                            child: const Icon(Icons.delete_sweep_outlined,
                                color: Colors.white),
                          ),
                          // ✨ 2. NỘI DUNG THÔNG BÁO (CAO HƠN)
                          child: InkWell(
                            onTap: () => _onNotificationTapped(notification),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isRead
                                      ? Colors.grey.shade200
                                      : primaryColor.withOpacity(0.5),
                                  width: isRead ? 1 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                // Icon
                                leading: CircleAvatar(
                                  backgroundColor: isRead
                                      ? Colors.grey.shade100
                                      : primaryColor.withOpacity(0.1),
                                  child: Icon(
                                    notification.type == 'new_web_order'
                                        ? Icons.cloud_download_outlined
                                        : Icons.campaign_outlined,
                                    size: 22,
                                    color:
                                        isRead ? Colors.grey.shade500 : primaryColor,
                                  ),
                                ),
                                
                                // ✨ 3. HIỂN THỊ TITLE VÀ SUBTITLE (NỘI DUNG)
                                title: Text(
                                  notification.title ?? notification.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.quicksand(
                                    fontSize: 16,
                                    color: Colors.black87,
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Chỉ hiển thị text ở đây nếu có title
                                    if (hasTitle)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          notification.text, // Nội dung
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.roboto(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: Colors.grey.shade700,
                                            fontWeight: isRead
                                                ? FontWeight.normal
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    // Thời gian
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        DateFormat('dd/MM/yyyy HH:mm')
                                            .format(notification.timestamp),
                                        style: GoogleFonts.roboto(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ),
                                  ],
                                ),
                                // Dấu chấm "chưa đọc"
                                trailing: isRead
                                    ? null
                                    : Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle,
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
        ),
      ),
    );
  }
}