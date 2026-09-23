import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lesson.dart';

class VideoPlayerScreen extends StatelessWidget {
  final Lesson lesson;

  const VideoPlayerScreen({
    super.key,
    required this.lesson,
  });

  Future<void> _playVideo(BuildContext context) async {
    if (lesson.contentUrl == null || lesson.contentUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video URL not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = Uri.parse(lesson.contentUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open video player'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lesson.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF5a189a),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.black,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              if (lesson.contentUrl != null && lesson.contentUrl!.isNotEmpty) ...[
                Icon(
                  Icons.play_circle_filled,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _playVideo(context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5a189a),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _playVideo(context),
                  child: Text(
                    'Open in External Player',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.video_library_outlined,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Video not available',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 18,
                  ),
                ),
              ],
              if (lesson.description != null && lesson.description!.isNotEmpty) ...[
                const SizedBox(height: 32),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lesson.description!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

