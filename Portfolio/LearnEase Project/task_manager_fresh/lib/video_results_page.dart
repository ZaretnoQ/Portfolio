import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/link.dart';           // your Link model
import 'services/yt_service.dart';  // your YouTube search service
import 'services/web_service.dart'; // your website search service

class VideoResultsPage extends StatefulWidget {
  final String query;
  const VideoResultsPage({required this.query, Key? key}) : super(key: key);

  @override
  _VideoResultsPageState createState() => _VideoResultsPageState();
}

class _VideoResultsPageState extends State<VideoResultsPage> {
  late Future<void> _loadFuture;
  List<Link> _ytLinks = [];
  List<Link> _webLinks = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadLinks(widget.query);
  }

  Future<void> _loadLinks(String query) async {
    try {
      final results = await Future.wait([
        YTService.searchVideos(query),
        WebService.searchWebsites(query),
      ]);
      _ytLinks = results[0];
      _webLinks = results[1];
    } catch (e) {
      _error = e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results for "${widget.query}"')),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null) {
              return Center(child: Text('Error: $_error'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // YouTube section
                  Text('YouTube Videos',
                      style: Theme.of(context).textTheme.headline6),
                  const SizedBox(height: 8),
                  if (_ytLinks.isEmpty)
                    const Text('No videos found')
                  else
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _ytLinks.length,
                        itemBuilder: (c, i) {
                          final link = _ytLinks[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Column(
                              children: [
                                Image.network(link.thumbnailUrl,
                                    width: 120, height: 90, fit: BoxFit.cover),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 120,
                                  child: Text(link.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const Divider(height: 32),

                  // Website section
                  Text('Websites',
                      style: Theme.of(context).textTheme.headline6),
                  const SizedBox(height: 8),
                  if (_webLinks.isEmpty)
                    const Text('No websites found')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _webLinks.length,
                      itemBuilder: (c, i) {
                        final link = _webLinks[i];
                        return ListTile(
                          title: Text(link.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(link.url,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _launchUrl(link.url),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }
}
