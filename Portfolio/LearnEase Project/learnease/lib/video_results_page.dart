import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'task_sorting.dart';

class VideoResultsPage extends StatelessWidget {
  final String query;
  final TaskSortingService sortingService;

  const VideoResultsPage(
      {super.key, required this.query, required this.sortingService});

  // helper to fetch title + thumb with oEmbed
  Future<Map<String, String>> _meta(String url) async {
    final id = url.split('v=').last.split('&').first;
    final thumb = 'https://img.youtube.com/vi/$id/0.jpg';
    String title = url;
    try {
      final r = await http.get(Uri.parse(
          'https://www.youtube.com/oembed?url=$url&format=json'));
      if (r.statusCode == 200) {
        title = (jsonDecode(r.body)['title'] as String?) ?? url;
      }
    } catch (_) {}
    return {'url': url, 'thumb': thumb, 'title': title};
  }

  Future<List<Map<String, String>>> _search() async {
    final urls = await sortingService.getYouTubeRecommendations(query);
    return Future.wait(urls.map(_meta));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Videos for “$query”')),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _search(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(snap.error.toString()));
          }
          final list = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, i) {
              final m = list[i];
              return ListTile(
                leading: Image.network(m['thumb']!, width: 64, fit: BoxFit.cover),
                title: Text(m['title']!, maxLines: 2),
                onTap: () => launchUrl(Uri.parse(m['url']!),
                    mode: LaunchMode.externalApplication),
              );
            },
          );
        },
      ),
    );
  }
}
