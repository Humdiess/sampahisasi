import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../widgets/skeleton_chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  late final GenerativeModel _model;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollButton = false;

  @override
  void initState() {
    super.initState();
    // Scroll listener for FAB visibility
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <
          _scrollController.position.maxScrollExtent - 200) {
        if (!_showScrollButton) setState(() => _showScrollButton = true);
      } else {
        if (_showScrollButton) setState(() => _showScrollButton = false);
      }
    });

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      _messages.add(
        Message(
          text: "Error: API Key not found. Please check .env file.",
          isUser: false,
        ),
      );
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-flash-lite-latest',
      apiKey: apiKey,
      systemInstruction: Content.system(
        "Kamu adalah asisten pintar aplikasi 'Sampahisasi'. "
        "Fokus utamamu adalah membantu pengguna mengidentifikasi dan memilah sampah (Organik, Anorganik, B3, dll). "
        "Berikan tips daur ulang yang praktis. "
        "Jika pengguna bertanya di luar topik sampah/lingkungan, arahkan kembali ke topik tersebut dengan sopan.",
      ),
      generationConfig: GenerationConfig(
        maxOutputTokens: 200,
        temperature: 0.7,
      ),
    );
    // Initial greeting
    _messages.add(
      Message(
        text:
            "Halo! Saya asisten SampahisasAI. Ada yang bisa saya bantu tentang pengelolaan sampah?",
        isUser: false,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom(); // Scroll on user message

    try {
      final content = [Content.text(text)];
      final response = await _model.generateContent(content);

      setState(() {
        _messages.add(
          Message(
            text: response.text ?? "Maaf, saya tidak mengerti.",
            isUser: false,
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom(); // Scroll on AI response
    } catch (e) {
      debugPrint("Gemini Error: $e");
      setState(() {
        _messages.add(
          Message(text: "Error: Gagal terhubung ke AI. ($e)", isUser: false),
        );
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Chat List (Behind everything)
          // Uses MediaQuery padding to avoid overlap with glass elements
          ListView.builder(
            controller: _scrollController,
            // Header height ~90, Input height ~90
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 70,
              16,
              100, // Proper bottom padding for floating input
            ),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return const SkeletonChatBubble();
              }

              final msg = _messages[index];
              return Align(
                alignment: msg.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? Colors.green.withOpacity(0.8)
                        : Colors.grey[800]!.withOpacity(0.8),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: msg.isUser
                          ? const Radius.circular(12)
                          : const Radius.circular(0),
                      bottomRight: msg.isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(12),
                    ),
                  ),
                  child: MarkdownBody(
                    data: msg.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white),
                      strong: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      em: const TextStyle(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                      ),
                      h1: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        color: Colors.white,
                        backgroundColor: Colors.grey[900],
                        fontFamily: 'monospace',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. Glass Header (Top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 10,
                    bottom: 15,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Tanya Sampahisasi",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Floating Glass Input (Bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              // Ensure top-only radius isn't too harsh if you want it merged primarily
              // But usually bar is just flat on bottom.
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6), // Darker glass
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Tanya sesuatu...",
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send Button
                      CircleAvatar(
                        backgroundColor: Colors.green,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Scroll to Bottom Button (FAB)
          // Positioned above the input bar
          if (_showScrollButton)
            Positioned(
              bottom: 100, // Above the input bar
              right: 16,
              child: ScaleTransition(
                scale: const AlwaysStoppedAnimation(1), // Simple for now
                child: GestureDetector(
                  onTap: _scrollToBottom,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[800]!.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Message {
  final String text;
  final bool isUser;

  Message({required this.text, required this.isUser});
}
