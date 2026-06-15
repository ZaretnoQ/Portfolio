// chatbot_page.dart  (keywords: "class" → classes list, "task" → tasks list, others → AI)
import 'package:flutter/material.dart';
import 'services/openai_service.dart';
import 'services/local_storage_service.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({Key? key}) : super(key: key);
  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final OpenAIService _openAIService = OpenAIService();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _controller.clear();
    });
    _scrollToBottom();

    final q = text.toLowerCase();

    /* --------------------------------------------------
     * 1️⃣ CLASS  → show saved class list
     * -------------------------------------------------- */
    if (RegExp(r'\bclass\b').hasMatch(q)) {
      try {
        final classes = await LocalStorageService.readList('classes');
        final reply = (classes == null || classes.isEmpty)
            ? 'You have no classes saved.'
            : classes.map((c) {
          final day = c['day'] ?? 'Day?';
          final h   = (c['startHour'] as int).toString().padLeft(2, '0');
          final m   = (c['startMinute'] as int).toString().padLeft(2, '0');
          final subj = c['subject'] ?? 'Subject';
          return '• $subj on $day at $h:$m';
        }).join('\n');
        setState(() => _messages.add({'sender': 'bot', 'text': reply}));
      } catch (_) {
        setState(() => _messages.add({'sender': 'bot', 'text': 'Sorry, I couldn’t read your classes.'}));
      }
      _scrollToBottom();
      return; // skip AI
    }

    /* --------------------------------------------------
     * 2️⃣ TASK  → show upcoming tasks
     * -------------------------------------------------- */
    if (RegExp(r'\btask\b|\bdeadline\b|\bdue\b').hasMatch(q)) {
      try {
        final raw = await LocalStorageService.readList('tasks');
        final List<Map<String, dynamic>> tasks = raw == null
            ? []
            : List<Map<String, dynamic>>.from(raw);

        final now = DateTime.now();
        final upcoming = tasks
            .where((t) {
          try {
            return DateTime.parse(t['date']).isAfter(now);
          } catch (_) {
            return false;
          }
        })
            .toList()
          ..sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

        final reply = upcoming.isEmpty
            ? 'You have no upcoming tasks.'
            : upcoming.take(5).map((t) {
          final due = DateTime.parse(t['date']);
          final dateStr = '${due.month}/${due.day} ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
          return '• ${t['task']} (due $dateStr)';
        }).join('\n');
        setState(() => _messages.add({'sender': 'bot', 'text': reply}));
      } catch (_) {
        setState(() => _messages.add({'sender': 'bot', 'text': 'Sorry, I couldn’t read your tasks.'}));
      }
      _scrollToBottom();
      return; // skip AI
    }

    /* --------------------------------------------------
     * 3️⃣ Normal AI call for everything else
     * -------------------------------------------------- */
    try {
      final response = await _openAIService.sendMessage(text);
      setState(() => _messages.add({'sender': 'bot', 'text': response}));
    } catch (_) {
      setState(() => _messages.add({'sender': 'bot', 'text': 'Failed to get response.'}));
    }
    _scrollToBottom();
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chatbot')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Theme.of(context).primaryColor : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
