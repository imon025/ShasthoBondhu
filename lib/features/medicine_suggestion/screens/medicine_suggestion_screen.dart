import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ollama_service.dart';

class MedicineSuggestionScreen extends StatefulWidget {
  const MedicineSuggestionScreen({super.key});

  @override
  State<MedicineSuggestionScreen> createState() => _MedicineSuggestionScreenState();
}

class _MedicineSuggestionScreenState extends State<MedicineSuggestionScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? 'guest';
  String get _sessionsListKey => 'chat_sessions_list_$_userId';

  List<Map<String, dynamic>> _sessions = [];
  String? _currentSessionId;
  final List<Map<String, String>> _messages = [];

  bool _isLoading = false;
  bool _isGenerating = false;
  bool _cancelGeneration = false;
  String _clinicalContext = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _loadSessions();
    _fetchClinicalContext();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final response = await Supabase.instance.client
          .from('medicine_chat_sessions')
          .select('id, title, updated_at')
          .eq('user_id', _userId)
          .order('updated_at', ascending: false);

      setState(() {
        _sessions = (response as List).map((e) => {
          'id': e['id'],
          'title': e['title'],
          'timestamp': e['updated_at'],
        }).toList();
      });

      if (_sessions.isNotEmpty) {
        _loadSession(_sessions.first['id']);
      } else {
        _createNewChat();
      }
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      if (_sessions.isEmpty) _createNewChat();
    }
  }

  Future<void> _loadSession(String sessionId) async {
    try {
      final response = await Supabase.instance.client
          .from('medicine_chat_sessions')
          .select('messages')
          .eq('id', sessionId)
          .maybeSingle();
      
      setState(() {
        _currentSessionId = sessionId;
        _messages.clear();
        if (response != null && response['messages'] != null) {
          final msgs = response['messages'] as List<dynamic>;
          _messages.addAll(msgs.map((e) => Map<String, String>.from(e)));
        }
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading session: $e');
      setState(() {
        _currentSessionId = sessionId;
        _messages.clear();
      });
    }
  }

  Future<void> _saveCurrentSession() async {
    if (_currentSessionId == null) return;
    
    final sessionIndex = _sessions.indexWhere((s) => s['id'] == _currentSessionId);
    String title = 'New Chat';
    if (sessionIndex != -1) {
      title = _sessions[sessionIndex]['title'];
    }

    if (title == 'New Chat' && _messages.isNotEmpty) {
      final firstUserMsg = _messages.firstWhere(
        (m) => m['role'] == 'user', 
        orElse: () => {'content': 'New Chat', 'role': 'user'}
      );
      title = firstUserMsg['content'] ?? 'New Chat';
      if (title.length > 25) title = '${title.substring(0, 25)}...';
      
      if (sessionIndex != -1) {
        setState(() {
          _sessions[sessionIndex]['title'] = title;
        });
      }
    }

    try {
      await Supabase.instance.client
          .from('medicine_chat_sessions')
          .upsert({
            'id': _currentSessionId,
            'user_id': _userId,
            'title': title,
            'messages': _messages,
            'updated_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  void _createNewChat() {
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
      _sessions.insert(0, {
        'id': _currentSessionId,
        'title': 'New Chat',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await Supabase.instance.client
          .from('medicine_chat_sessions')
          .delete()
          .eq('id', sessionId);
          
      setState(() {
        _sessions.removeWhere((s) => s['id'] == sessionId);
      });
      
      if (_sessions.isNotEmpty) {
        _loadSession(_sessions.first['id']);
      } else {
        _createNewChat();
      }
    } catch (e) {
      debugPrint('Error deleting session: $e');
    }
  }


  Future<void> _fetchClinicalContext() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final response = await Supabase.instance.client
          .from('user_reports')
          .select('title, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(5);

      if (response.isNotEmpty) {
        final reportsStr = (response as List).map((e) {
          final title = e['title'];
          final date = DateTime.parse(e['created_at']);
          return '- $title (Uploaded on ${date.day}/${date.month}/${date.year})';
        }).join('\n');
        
        if (mounted) {
          setState(() {
            _clinicalContext = 'The user has the following clinical reports in their history:\n$reportsStr';
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch clinical context: $e');
    }
  }

  void _stopGeneration() {
    setState(() {
      _cancelGeneration = true;
    });
  }

  void _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty) return;

    final historyForService = List<Map<String, String>>.from(_messages);

    _cancelGeneration = false;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messages.add({'role': 'assistant', 'content': ''});
      _isLoading = true;
      _isGenerating = true;
    });
    
    _saveCurrentSession();

    if (presetText == null) {
      _controller.clear();
    }
    _scrollToBottom();

    final assistantIndex = _messages.length - 1;

    try {
      final stream = OllamaService.streamMessage(text, historyForService, ragContext: _clinicalContext);
      
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
      _saveCurrentSession();
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isGenerating = false;
      });
      _saveCurrentSession();
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

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.blur_circular,
              size: 70,
              color: Colors.green[400],
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestionChip('General checkup', 'for common symptoms', Icons.monitor_heart),
                  _buildSuggestionChip('Dietary advice', 'for better health', Icons.restaurant_menu),
                  _buildSuggestionChip('Review my history', 'based on reports', Icons.history_edu),
                  _buildSuggestionChip('Skin conditions', 'common treatments', Icons.spa),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String title, String subtitle, IconData icon) {
    return InkWell(
      onTap: () {
        _sendMessage('$title $subtitle');
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.42,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.green, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAF8),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.black54, size: 20),
                            const SizedBox(width: 8),
                            const Text('Search', style: TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final isSelected = session['id'] == _currentSessionId;
                    return ListTile(
                      title: Text(
                        session['title'] ?? 'New Chat',
                        style: TextStyle(
                          color: isSelected ? Colors.green[800] : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: isSelected,
                      selectedTileColor: Colors.green[50],
                      onTap: () {
                        _loadSession(session['id']);
                        Navigator.pop(context);
                      },
                      trailing: isSelected
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.black54, size: 20),
                              onPressed: () => _deleteSession(session['id']),
                            )
                          : null,
                    );
                  },
                ),
              ),
              Divider(color: Colors.grey[300]),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.black87),
                title: const Text('My Profile', style: TextStyle(color: Colors.black87)),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.green[800]),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: GestureDetector(
          onTap: () {},
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Health Assistant 4o',
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: Colors.black54, size: 20),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, size: 22),
            onPressed: _createNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      if (msg['role'] == 'system' || (msg['content'] ?? '').isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.health_and_safety,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                            Flexible(
                              child: Container(
                                padding: isUser 
                                    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                                    : EdgeInsets.zero,
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.green.shade100 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(
                                      msg['content'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (!isUser && (msg['content'] ?? '').isNotEmpty && !_isGenerating)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: msg['content'] ?? ''));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                                            );
                                          },
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.copy_rounded, size: 16, color: Colors.black54),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Generating...', style: TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controller,
                      enabled: !_isGenerating,
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: _isGenerating ? 'Generating...' : 'Message',
                        hintStyle: const TextStyle(color: Colors.black54),
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _isGenerating ? null : (_) => _sendMessage(),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.add, color: Colors.black54),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.language, color: Colors.blue, size: 16),
                              SizedBox(width: 6),
                              Text('Search', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.mic, color: Colors.black54),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isGenerating ? _stopGeneration : () => _sendMessage(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isGenerating ? Colors.grey[200] : (_controller.text.trim().isEmpty ? Colors.grey[200] : Colors.green),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isGenerating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                              color: _isGenerating ? Colors.black54 : (_controller.text.trim().isEmpty ? Colors.black54 : Colors.white),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
