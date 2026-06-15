import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TaskSortingService {
  static const _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  final String apiKey;
  TaskSortingService(this.apiKey);

  // in‑memory cache for YouTube lists
  final Map<String, List<String>> _ytCache = {};

  // ------------------- call helper
  Future<String> _call(String prompt) async {
    final res = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek/deepseek-chat-v3-0324:free',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 800,
        'temperature': 0.3,
      }),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode != 200 || data['choices'] == null) {
      throw Exception('OpenRouter error: ${res.statusCode} – ${res.body}');
    }
    return data['choices'][0]['message']['content'];
  }

// ADD just inside TaskSortingService – nothing else modified
  final Map<String, List<String>> _webCache = {};

  Future<List<String>> getWebsiteRecommendations(String topic) async {
    if (_webCache.containsKey(topic)) return _webCache[topic]!;
    final prompt =
        'List 5 high-quality website URLs (one per line) about: "$topic".';
    final raw = await _call(prompt);          // uses your existing _call()
    final links = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('http'))
        .toList();
    _webCache[topic] = links;
    return links;
  }

  Future<List<String>> getYouTubeRecommendations(String task) async {
    if (_ytCache.containsKey(task)) return _ytCache[task]!;

    final prompt =
        'Give me 5 direct YouTube video URLs (one per line) for the topic: "$task".';

    final raw = await _call(prompt);
    final links = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.startsWith('http'))
        .toList();

    _ytCache[task] = links;
    return links;
  }

  // ------------------- AI sort
  Future<String> sortTasksWithDeepSeek(
      List<Map<String, dynamic>> tasks) async {
    final desc = tasks
        .map((t) =>
    '${t['task']} | Due ${DateFormat('MMM dd').format(t['date'])} | ${t['difficulty']}')
        .join('\n');

    final prompt =
        'Sort these by priority (hard + close first). Return ONLY original task names, one per line.\n$desc';

    return _call(prompt);
  }

  // ------------------- generic helper
  Future<String> simplePrompt(String prompt) => _call(prompt);
}
