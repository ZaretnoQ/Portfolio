import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  final _apiKey = dotenv.env['OPENAI_API_KEY'];

  Future<String> getChatResponse(String message) async {
    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: json.encode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": message},
        ],
      }),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return decoded['choices'][0]['message']['content'];
    } else {
      return 'Failed to get response';
    }
  }
}
