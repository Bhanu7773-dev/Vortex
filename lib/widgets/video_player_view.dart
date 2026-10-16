import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

class VideoPlayerView extends StatefulWidget {
  final String videoPath;
  final String title;

  const VideoPlayerView({
    Key? key,
    required this.videoPath,
    required this.title,
  }) : super(key: key);

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    try {
      await _controller.initialize();
      _controller.addListener(_onControllerUpdate);
      await _controller.play();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _startHideTimer();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _initialized = false;
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_controller.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller.value.isPlaying) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      _hideTimer?.cancel();
      setState(() {
        _showControls = true;
      });
    } else {
      _controller.play();
      setState(() {});
      _startHideTimer();
    }
  }

  void _seekRelative(int seconds) {
    final current = _controller.value.position;
    final target = current + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _controller.value.duration
            ? _controller.value.duration
            : target);
    _controller.seekTo(clamped);
    _startHideTimer();
  }

  void _toggleRotation() {
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    });
  }

  void _showSpeedSheet() {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121513),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isNormal = _playbackSpeed == 1.0;
            final labelText = isNormal
                ? 'Normal'
                : (_playbackSpeed > 1.0 ? 'Faster' : 'Slower');

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3F3C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      'Playback speed',
                      style: TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: _playbackSpeed == _playbackSpeed.roundToDouble()
                                    ? '${_playbackSpeed.toStringAsFixed(1)}'
                                    : '$_playbackSpeed',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 46,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                              const TextSpan(
                                text: ' ×',
                                style: TextStyle(
                                  color: AppTheme.accentLime,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          labelText,
                          style: const TextStyle(
                            color: Color(0xFF78828A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.55,
                      ),
                      itemCount: speeds.length,
                      itemBuilder: (context, i) {
                        final sp = speeds[i];
                        final isSel = sp == _playbackSpeed;
                        final spText = sp == sp.roundToDouble()
                            ? '${sp.toStringAsFixed(1)}×'
                            : '${sp}×';

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _playbackSpeed = sp;
                            });
                            setSheetState(() {});
                            _controller.setPlaybackSpeed(sp);
                            Navigator.pop(sheetContext);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppTheme.accentLime
                                  : const Color(0xFF161917),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSel
                                    ? AppTheme.accentLime
                                    : const Color(0xFF262A28),
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              spText,
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetails() {
    final file = File(widget.videoPath);
    final stat = file.existsSync() ? file.statSync() : null;
    final sizeKB = (stat?.size ?? 0) / 1024;
    final sizeMB = sizeKB / 1024;
    final sizeStr = sizeMB >= 1
        ? '${sizeMB.toStringAsFixed(1)} MB'
        : '${sizeKB.toStringAsFixed(1)} KB';
    final date = stat?.modified ?? DateTime.now();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final durStr = _formatDuration(_controller.value.duration);
    final resStr = _controller.value.isInitialized
        ? '${_controller.value.size.width.toInt()} × ${_controller.value.size.height.toInt()}'
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121513),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3F3C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'FILE INFO',
                  style: TextStyle(
                    color: Color(0xFF78828A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontBricolage,
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF1E2220), height: 28, thickness: 1),
                _buildInfoRow('Size', sizeStr),
                const Divider(color: Color(0xFF1E2220), height: 28, thickness: 1),
                _buildInfoRow('Duration', durStr),
                if (resStr != null) ...[
                  const Divider(color: Color(0xFF1E2220), height: 28, thickness: 1),
                  _buildInfoRow('Resolution', resStr),
                ],
                const Divider(color: Color(0xFF1E2220), height: 28, thickness: 1),
                _buildInfoRow('Modified', dateStr),
                const Divider(color: Color(0xFF1E2220), height: 28, thickness: 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Path',
                      style: TextStyle(
                        color: Color(0xFF78828A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        file.path,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: file.path));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Path copied to clipboard',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: const Color(0xFF1C1F1D),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161917),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF262A28), width: 1.2),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Copy path',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF78828A),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _hideTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    final isPlaying = _controller.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          color: const Color(0xFF161917),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: Color(0xFF262A28),
                              width: 1,
                            ),
                          ),
                          onSelected: (val) {
                            if (val == 'details') _showDetails();
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'details',
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Details',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: _initialized
                          ? AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: VideoPlayer(_controller),
                            )
                          : const CircularProgressIndicator(
                              color: AppTheme.accentLime,
                            ),
                    ),

                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => _seekRelative(-10),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.52),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.replay_10_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              InkWell(
                                onTap: _togglePlayPause,
                                borderRadius: BorderRadius.circular(38),
                                child: Container(
                                  width: 66,
                                  height: 66,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.accentLime,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x55C6F36B),
                                        blurRadius: 18,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 38,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              InkWell(
                                onTap: () => _seekRelative(10),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.52),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.forward_10_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(pos),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        _formatDuration(dur),
                        style: const TextStyle(
                          color: Color(0xFF78828A),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  _TallyProgressBar(
                    position: pos,
                    duration: dur,
                    onSeek: (newPos) {
                      _controller.seekTo(newPos);
                      _startHideTimer();
                    },
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: _showSpeedSheet,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161917),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF262A28),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.speed_rounded,
                                color: AppTheme.accentLime,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _playbackSpeed == _playbackSpeed.roundToDouble()
                                    ? '${_playbackSpeed.toStringAsFixed(1)}×'
                                    : '${_playbackSpeed}×',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      IconButton(
                        icon: const Icon(
                          Icons.screen_rotation_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Rotate screen',
                        onPressed: _toggleRotation,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TallyProgressBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _TallyProgressBar({
    Key? key,
    required this.position,
    required this.duration,
    required this.onSeek,
  }) : super(key: key);

  @override
  State<_TallyProgressBar> createState() => _TallyProgressBarState();
}

class _TallyProgressBarState extends State<_TallyProgressBar> {
  double? _dragFraction;

  void _handleTouch(double dx, double width) {
    final frac = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragFraction = frac);
    widget.onSeek(widget.duration * frac);
  }

  @override
  Widget build(BuildContext context) {
    final totalMillis = widget.duration.inMilliseconds;
    final currentMillis = totalMillis <= 0
        ? 0
        : (_dragFraction != null
            ? (totalMillis * _dragFraction!).toInt()
            : widget.position.inMilliseconds);
    final progress = totalMillis <= 0 ? 0.0 : (currentMillis / totalMillis).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const tickWidth = 3.6;
        const tickMargin = 2.0;
        const tickPitch = tickWidth + (tickMargin * 2);
        final tickCount = (totalWidth / tickPitch).floor();
        if (tickCount <= 0) return const SizedBox(height: 32);

        final playedCount = (progress * tickCount).round();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleTouch(details.localPosition.dx, totalWidth),
          onHorizontalDragStart: (details) => _handleTouch(details.localPosition.dx, totalWidth),
          onHorizontalDragUpdate: (details) => _handleTouch(details.localPosition.dx, totalWidth),
          onHorizontalDragEnd: (_) => setState(() => _dragFraction = null),
          onHorizontalDragCancel: () => setState(() => _dragFraction = null),
          child: Container(
            height: 34,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(tickCount, (i) {
                final isPlayed = i < playedCount;
                return Container(
                  width: tickWidth,
                  height: 26.0,
                  decoration: BoxDecoration(
                    color: isPlayed ? AppTheme.accentLime : const Color(0xFF262C27),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
