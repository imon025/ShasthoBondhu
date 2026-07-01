import 'package:flutter/material.dart';
import '../services/ollama_service.dart';

class MedicineSuggestionScreen extends StatefulWidget {
  const MedicineSuggestionScreen({super.key});

  @override
  State<MedicineSuggestionScreen> createState() => _MedicineSuggestionScreenState();
}

class _MedicineSuggestionScreenState extends State<MedicineSuggestionScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isGenerating = false;
  bool _cancelGeneration = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add an initial greeting message from the AI
    _messages.add({
      'role': 'assistant',
      'content': 'Hello! I am your AI Medical Assistant powered by Ollama. Please describe your symptoms or ask for medicine suggestions. Note: I am an AI, so please consult a real doctor for serious conditions.',
    });
  }

  void _stopGeneration() {
    setState(() {
      _cancelGeneration = true;
    });
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final historyForService = List<Map<String, String>>.from(_messages);

    _cancelGeneration = false;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messages.add({'role': 'assistant', 'content': ''});
      _isLoading = true;
      _isGenerating = true;
    });
    
    _controller.clear();
    _scrollToBottom();

    final assistantIndex = _messages.length - 1;

    try {
      final stream = OllamaService.streamMessage(text, historyForService);
      
      await for (final chunk in stream) {
        if (!mounted || _cancelGeneration) break;
        setState(() {
          _messages[assistantIndex] = {
            'role': 'assistant',
            'content': (_messages[assistantIndex]['content'] ?? '') + chunk,
          };
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[assistantIndex] = {
          'role': 'assistant',
          'content': 'Error: $e',
        };
        _isLoading = false;
        _isGenerating = false;
      });
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isGenerating = false;
      });
      _scrollToBottom();
    }
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF436B46);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text(
          'Medicine Suggestion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                // System messages or empty messages are not displayed
                if (msg['role'] == 'system' || (msg['content'] ?? '').isEmpty) {
                  return const SizedBox.shrink();
                }

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUser ? primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
                        bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('AI is typing...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isGenerating,
                      decoration: InputDecoration(
                        hintText: _isGenerating ? 'Generating response...' : 'Describe your symptoms...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: const Color(0xFFF5F6F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _isGenerating ? null : (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _isGenerating ? Colors.redAccent : primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(_isGenerating ? Icons.stop_rounded : Icons.send_rounded, color: Colors.white),
                      onPressed: _isGenerating ? _stopGeneration : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
