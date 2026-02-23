import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';

class AudioPlayerSheet extends StatefulWidget {
  final String audioPath;
  final String title;

  const AudioPlayerSheet({
    Key? key,
    required this.audioPath,
    required this.title,
  }) : super(key: key);

  static void show(BuildContext context, String path, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AudioPlayerSheet(audioPath: path, title: title),
    );
  }

  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet> {
  late AudioPlayer _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });

    await _audioPlayer.play(DeviceFileSource(widget.audioPath));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.music_note, size: 64, color: AppTheme.accentBlue),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          Slider(
            min: 0,
            max: _duration.inMilliseconds.toDouble(),
            value: _position.inMilliseconds.toDouble().clamp(
              0,
              _duration.inMilliseconds.toDouble(),
            ),
            activeColor: AppTheme.accentBlue,
            inactiveColor: Colors.white12,
            onChanged: (value) async {
              final position = Duration(milliseconds: value.toInt());
              await _audioPlayer.seek(position);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () =>
                    _audioPlayer.seek(_position - const Duration(seconds: 10)),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () {
                  if (_playerState == PlayerState.playing) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.resume();
                  }
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _playerState == PlayerState.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                iconSize: 32,
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () =>
                    _audioPlayer.seek(_position + const Duration(seconds: 10)),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
