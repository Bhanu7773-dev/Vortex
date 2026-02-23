import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../widgets/video_player_view.dart';
import '../widgets/audio_player_sheet.dart';

class FileOpener {
  static const _videoExts = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    '3gp',
    'm4v',
  };
  static const _audioExts = {
    'mp3',
    'wav',
    'flac',
    'aac',
    'ogg',
    'm4a',
    'wma',
    'opus',
  };

  static Future<void> openFile(BuildContext context, String path) async {
    final ext = path.split('.').last.toLowerCase();
    final name = path.split('/').last;

    if (_videoExts.contains(ext)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerView(videoPath: path, title: name),
        ),
      );
    } else if (_audioExts.contains(ext)) {
      AudioPlayerSheet.show(context, path, name);
    } else {
      // Use open_filex for EVERYTHING else (PDFs, Docs, APKs, etc.)
      try {
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    }
  }
}
