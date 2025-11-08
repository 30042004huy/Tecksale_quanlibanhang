import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class HoTroScreen extends StatefulWidget {
  const HoTroScreen({Key? key}) : super(key: key);

  @override
  _HoTroScreenState createState() => _HoTroScreenState();
}

class _HoTroScreenState extends State<HoTroScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;

  // API key Gemini
  final String _geminiApiKey = 'AIzaSyBy4DpZ43OtU65hZKmeeu7ZaDBi2buyYZM';
  final String _apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  @override
  void initState() {
    super.initState();
    _loadMessages().then((_) {
      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }
      _scrollToBottom();
    });
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: '🤖 Xin chào! Tôi là trợ lý AI của TeckSale.\n\n'
          'Bạn cần tôi hỗ trợ điều gì?\n'
          '💬 Để tạo tài khoản, vui lòng click nút hỗ trợ viên ở góc trên bên phải!\n\n'
          '💡 TeckSale đồng hành cùng bạn quản lý bán hàng thông minh.',
      isUser: false,
      timestamp: DateTime.now(),
    ));
    _saveMessages();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getString('chat_messages');
    if (messagesJson != null) {
      final List<dynamic> decoded = jsonDecode(messagesJson);
      final now = DateTime.now();
      setState(() {
        _messages = decoded
            .map((m) => ChatMessage.fromJson(m))
            .where((m) => now.difference(m.timestamp).inMinutes < 5)
            .toList();
      });
      _saveMessages();
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    _messages.removeWhere((m) => now.difference(m.timestamp).inMinutes >= 10);
    final messagesJson = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString('chat_messages', messagesJson);
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _addUserMessage(text);
    _messageController.clear();
    FocusScope.of(context).unfocus();
    _scrollToBottom();

    setState(() {
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await _sendToGemini(text);
      _addBotMessage(response);
    } catch (e) {
      _addBotMessage('Xin lỗi, có lỗi xảy ra: $e. Vui lòng thử lại.');
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    _saveMessages();
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _saveMessages();
  }

  Future<String> _sendToGemini(String prompt) async {
    final client = http.Client();
    try {
      print('DEBUG: Sending to Gemini - Text: "$prompt"');
      
      final Map<String, dynamic> content = {
        "parts": [
          {
            "text": "Bạn là trợ lý AI của ứng dụng TeckSale - Quản Lý Bán Hàng, sử dụng mô hình Gemini 4.0 Pro. "
                "Trả lời ngắn gọn, hữu ích, thân thiện bằng tiếng Việt. "
                "Dựa trên thông tin sau để trả lời:\n"
                "- Tên ứng dụng: TeckSale Quản Lý Bán Hàng\n"
                "- Thông tin liên hệ: Click nút hỗ trợ viên ở góc trên bên phải\n"
                "- Chủ app, thiết kế, bản quyền: Huy Lữ\n"
                "- Cách đăng ký tài khoản: Liên hệ hỗ trợ viên\n"
                "- Bạn là AI: Gemini 5.0 Pro, phiên bản mới và cao cấp nhất hiện nay, thông tin được cập nhật tới thời gian hiện tại\n"
                "- Hack app: Không được hack, Huy Lữ sẽ đánh vô đít bạn đấy!\n"
                "- Chi phí: TeckSale đang thử nghiệm miễn phí\n"
                "- Huy Lữ là ai: Lữ Trọng Huy, người sáng lập và thiết kế TeckSale\n"
                "- Tecksale có chức năng gì: Tạo đơn hàng, quản lý sản phẩm tồn kho, quản lý khách hàng, tạo hóa đơn, tạo thanh toán nhanh, hỗ trợ viên AI\n"
                "- Gọi Huy Lữ: Đại ca đang bận không được làm phiền, nếu cần thì nhắn tin qua zalo nhé cưng\n"
                "- Hack app được không: Huy Lữ đấm chít đấy đừng dại dột nhanha \n"
                "- Tạo đơn, sản phẩm: Để tạo đơn hàng bạn nhớ thêm sản phẩm trước nha, để thêm sản phẩm bạn vui lòng truy cập trang sản phẩm. \n"
                "- Tạo QR: Bạn hãy nhập thông tin ở trang tạo qr nha, hoặc điền ở thông tin cửa hàng để được tự động nhập \n"
                "- Báo cáo sai: Bạn sai thì có ấy\n"
                "- Ứng dụng lỗi: Có bạn lỗi ấy, anh Huy đã làm là không lỗi.\n"
                "- Cách đổi mật khẩu, cách lấy lại mật khẩu, cách đổi email, mọi thứ liên quan đến app và tài khoản: liên hệ qua email hỗ trợ Tecksale04@gmail.com\n"
                "- Thời gian lưu trữ đoạn chat: Các tin nhắn chat sau 10 phút sẽ tự động xóa, không thể khôi phục\n"
                "- Trả lời ngắn gọn, đúng trọng tâm, trả lời rõ ràng, câu chat sau vẫn phải nhớ tới câu hỏi trước của người dùng và nhớ cả những câu trả lời của mình\n"

                "Câu hỏi của người dùng: $prompt"
          }
        ]
      };

      final response = await client.post(
        Uri.parse('$_apiUrl?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [content],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 1024,
          }
        }),
      );

      print('DEBUG: API Response - Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final responseText = parts[0]['text'] ?? 'Không có phản hồi.';
            print('DEBUG: AI response: $responseText');
            return responseText;
          }
        }
        return 'Không có phản hồi từ AI.';
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return 'Gemini đang bận đi nghỉ dưỡng vui lòng thử lại sau khi gemini quay lại làm việc.';
      }
    } catch (e) {
      print('Network Error: $e');
      return 'Lỗi mạng: $e. Vui lòng kiểm tra kết nối.';
    } finally {
      client.close();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            'Trợ lý TeckSale AI',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black26,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, size: 22),
              onPressed: () => _showInfoDialog(),
              tooltip: 'Về Trợ lý AI',
            ),
            IconButton(
              icon: const Icon(Icons.support_agent, size: 22),
              onPressed: () => _showSupportDialog(),
              tooltip: 'Liên hệ hỗ trợ',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE8F0FE), Color(0xFFF5F7FA)],
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessage(_messages[index]);
                  },
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _messageController,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'Nhập tin nhắn...',
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          tooltip: 'Gửi tin nhắn',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final timeFormat = DateFormat('HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            _buildAvatar(false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser ? Theme.of(context).primaryColor : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(message.isUser ? 10 : 12),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        fontSize: message.isUser ? 13 : 14,
                        color: message.isUser ? Colors.white : Colors.black87,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormat.format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: isUser
            ? Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              )
            : Image.asset(
                'assets/images/logoAI.png',
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(false),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 120)),
      builder: (context, value, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[400]!.withOpacity(0.4 + (value * 0.6)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.info, color: Theme.of(context).primaryColor, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Về Trợ lý AI',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trợ lý AI TeckSale',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              SizedBox(height: 8),
              Text(
                '• Hỗ trợ sử dụng ứng dụng\n'
                '• Liên hệ hỗ trợ qua thông tin ở góc trên bên phải\n'
                '• Hướng dẫn tính năng\n'
                '• Tư vấn kỹ thuật\n\n'
                'Tin nhắn được lưu tạm thời và tự động xóa sau 10 phút.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Đóng',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.support_agent, color: Theme.of(context).primaryColor, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Liên hệ hỗ trợ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSupportItem(
                  context,
                  "assets/images/logomess.png",
                  "Messenger",
                  () => launchUrl(
                    Uri.parse("http://m.me/107005565374824"),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSupportItem(
                  context,
                  "assets/images/logozalo.png",
                  "Zalo",
                  () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      contentPadding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset("assets/images/qrzalo.jpg", width: 200),
                            const SizedBox(height: 12),
                            const Text(
                              "Quét mã QR bằng Zalo để được hỗ trợ",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Đóng',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSupportItem(
                  context,
                  "assets/images/logogmail.png",
                  "Email",
                  () => launchUrl(
                    Uri.parse("mailto:Tecksale04@gmail.com"),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Đóng',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSupportItem(BuildContext context, String imagePath, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Image.asset(imagePath, width: 28, height: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isUser: json['isUser'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}