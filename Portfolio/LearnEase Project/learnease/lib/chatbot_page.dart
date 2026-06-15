import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];

  bool _loading = false;

  Future<void> _sendMessage() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _loading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': input});
      _loading = true;
      _controller.clear();
    });

    try {
      final res = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['OPENROUTER_API_KEY']}',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo', // or use "deepseek/deepseek-chat-v3-0324:free"
          'messages': _messages,
          'temperature': 0.7,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final reply = data['choices'][0]['message']['content'];

        setState(() {
          _messages.add({'role': 'assistant', 'content': reply});
          _loading = false;
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '⚠️ OpenRouter Error (${res.statusCode}): ${res.body}'
          });
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '⚠️ Network or parsing error: $e'
        });
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final yellowDark = Color(0xFFFFC107);
    final bubble = (String role, String msg) => Align(
      alignment:
      role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: role == 'user' ? yellowDark : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg,
          style: TextStyle(
              color: role == 'user' ? Colors.black : Colors.black87),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("LearnEase Chatbot")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return bubble(m['role']!, m['content']!);
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding:
            const EdgeInsets.only(left: 12, right: 8, bottom: 12, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: yellowDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
