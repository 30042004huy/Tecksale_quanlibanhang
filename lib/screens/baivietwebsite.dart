// lib/screens/baivietwebsite.dart
// (PHIÊN BẢN NÂNG CẤP HOÀN CHỈNH)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// Model cơ bản cho bài viết
class Article {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final int timestamp;

  Article({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.timestamp,
  });

  factory Article.fromMap(String id, Map<dynamic, dynamic> map) {
    return Article(
      id: id,
      title: map['title'] ?? 'Không có tiêu đề',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      timestamp: map['timestamp'] ?? 0,
    );
  }
}

class BaiVietWebsiteScreen extends StatefulWidget {
  const BaiVietWebsiteScreen({super.key});

  @override
  State<BaiVietWebsiteScreen> createState() => _BaiVietWebsiteScreenState();
}

class _BaiVietWebsiteScreenState extends State<BaiVietWebsiteScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  late DatabaseReference _articlesRef;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _articlesRef = FirebaseDatabase.instance
          .ref('website_data/${user!.uid}/articles');
    }
  }

  // Hàm mở trình soạn thảo (dạng Bottom Sheet)
  void _showArticleEditor({Article? article}) {
    final _titleController = TextEditingController(text: article?.title);
    final _contentController = TextEditingController(text: article?.content);
    final _imageUrlController = TextEditingController(text: article?.imageUrl);
    final _formKey = GlobalKey<FormState>();
    bool _isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  top: 20, left: 16, right: 16),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article == null ? 'Tạo bài viết mới' : 'Chỉnh sửa bài viết',
                        style: GoogleFonts.quicksand(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tiêu đề bài viết',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Tiêu đề không được rỗng' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung bài viết',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 8,
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Nội dung không được rỗng' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Link ảnh bìa (Không bắt buộc)',
                          hintText: 'https://example.com/image.png',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.public),
                        label: Text(article == null ? 'Đăng bài' : 'Cập nhật'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: _isSubmitting ? null : () {
                          if (_formKey.currentState!.validate()) {
                            _publishArticle(
                              title: _titleController.text,
                              content: _contentController.text,
                              imageUrl: _imageUrlController.text,
                              existingArticle: article,
                              setSubmitting: (bool isSubmitting) {
                                setSheetState(() => _isSubmitting = isSubmitting);
                              },
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Hàm lưu bài viết lên Firebase
  Future<void> _publishArticle({
    required String title,
    required String content,
    required String imageUrl,
    required Function(bool) setSubmitting,
    Article? existingArticle,
  }) async {
    if (user == null) return;
    setSubmitting(true);

    try {
      final Map<String, dynamic> articleData = {
        'title': title,
        'content': content,
        'imageUrl': imageUrl.isNotEmpty ? imageUrl : null,
        'timestamp': ServerValue.timestamp,
      };

      DatabaseReference postRef;
      if (existingArticle != null) {
        // Cập nhật bài viết cũ
        postRef = _articlesRef.child(existingArticle.id);
      } else {
        // Tạo bài viết mới
        postRef = _articlesRef.push(); // Tự động tạo ID
      }
      
      await postRef.set(articleData);

      Navigator.of(context).pop(); // Đóng bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existingArticle == null ? 'Đăng bài thành công!' : 'Cập nhật thành công!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setSubmitting(false);
    }
  }

  // Hàm xóa bài viết
  Future<void> _deleteArticle(String id) async {
     try {
       await _articlesRef.child(id).remove();
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Đã xóa bài viết'), backgroundColor: Colors.orange),
       );
     } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Lỗi khi xóa: $e'), backgroundColor: Colors.red),
       );
     }
  }


  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bài viết SEO')),
        body: const Center(child: Text('Vui lòng đăng nhập để quản lý bài viết.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Bài viết SEO', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: _articlesRef.orderByChild('timestamp').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có bài viết nào',
                    style: GoogleFonts.roboto(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Nhấn + để tạo bài viết đầu tiên', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Đọc và sắp xếp dữ liệu (mới nhất lên đầu)
          final Map<dynamic, dynamic> data = snapshot.data!.snapshot.value as Map;
          final List<Article> articles = data.entries.map((entry) {
            return Article.fromMap(entry.key, entry.value as Map<dynamic, dynamic>);
          }).toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Sắp xếp mới nhất lên đầu

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: article.imageUrl != null
                      ? Image.network(
                          article.imageUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, e, s) => const Icon(Icons.image_not_supported, size: 50),
                        )
                      : const Icon(Icons.article, size: 50),
                  title: Text(article.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Đăng ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(article.timestamp))}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showArticleEditor(article: article),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteArticle(article.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showArticleEditor(),
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}