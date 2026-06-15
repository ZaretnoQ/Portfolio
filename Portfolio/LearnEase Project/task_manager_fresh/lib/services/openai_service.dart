import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  final _apiKey =
  dotenv.env['OPENROUTER_API_KEY'];              // keep your OR key

  Future<String> getChatResponse(String message) async {
    // 1️⃣  Use OpenRouter host
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    // 2️⃣  Everything else is the same JSON schema
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',          // OR key works here
      },
      body: json.encode({
        "model": "gpt-3.5-turbo",                    // OR proxies this model
        "messages": [
          {"role": "user", "content": message},
        ],
      }),
    );

    print('← status ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['choices'][0]['message']['content'];
    } else {
      return 'Chat error (${response.statusCode})';
    }
  }

  Future<String> sendMessage(String prompt) => getChatResponse(prompt);
}
