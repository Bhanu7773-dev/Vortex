import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme/app_theme.dart';
import '../widgets/share_sheet.dart';
import '../viewmodels/media_viewmodels.dart';
import '../utils/file_opener.dart';

class AudioView extends StatefulWidget {
  const AudioView({Key? key}) : super(key: key);

  @override
  State<AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<AudioView>
    with SingleTickerProviderStateMixin {
  static const _exts = {
    'mp3',
    'wav',
    'flac',
    'aac',
    'ogg',
    'm4a',
    'wma',
    'opus',
  };
  static const _filters = ['All', 'MP3', 'OPUS', 'WAV', 'M4A', 'FLAC', 'AAC'];

  final _searchFocus = FocusNode();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  late final AudioPlayer _player;
  late final AnimationController _waveAnimController;
  String? _activeAudioPath;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _compSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _playerState = state);
        if (state == PlayerState.playing) {
          if (!_waveAnimController.isAnimating) {
            _waveAnimController.repeat(reverse: true);
          }
        } else {
          _waveAnimController.stop();
        }
      }
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _compSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
        _waveAnimController.stop();
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _compSub?.cancel();
    _waveAnimController.dispose();
    _player.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(MediaFileItem item) async {
    final path = item.file.path;
    if (_activeAudioPath == path) {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
    } else {
      _activeAudioPath = path;
      _position = Duration.zero;
      _duration = Duration.zero;
      setState(() {});
      try {
        await _player.stop();
        await _player.play(DeviceFileSource(path));
      } catch (e) {
        debugPrint('Audio playback error: $e');
      }
    }
  }

  Future<void> _seekAudio(MediaFileItem item, double ratio) async {
    final path = item.file.path;
    if (_activeAudioPath != path) {
      await _toggleAudio(item);
    }
    if (_duration.inMilliseconds > 0) {
      final targetMs = (ratio * _duration.inMilliseconds).round();
      await _player.seek(Duration(milliseconds: targetMs));
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MediaListViewModel(_exts),
      child: Consumer<MediaListViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentLime),
                )
              : Column(
                  children: [
                    if (!vm.isSelectionMode) ...[
                      _PillFilterBar(
                        filters: _filters,
                        active: vm.activeFilter,
                        onSelect: vm.applyFilter,
                      ),
                      _MediaCountHeader(
                        count: vm.filteredItems.length,
                        noun: 'item',
                      ),
                    ],
                    Expanded(
                      child: vm.filteredItems.isEmpty
                          ? _EmptyMediaState(
                              icon: Icons.music_off_outlined,
                              label: _searching && _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No audio files found',
                            )
                          : AnimatedBuilder(
                              animation: _waveAnimController,
                              builder: (context, _) {
                                return ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 30),
                                  itemCount: vm.filteredItems.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    color: Color(0xFF16191E),
                                    height: 1,
                                    thickness: 1,
                                  ),
                                  itemBuilder: (context, i) {
                                    final item = vm.filteredItems[i];
                                    final isSelected = vm.selectedPaths
                                        .contains(item.file.path);
                                    final isCurrent =
                                        _activeAudioPath == item.file.path;
                                    final isPlaying = isCurrent &&
                                        _playerState == PlayerState.playing;
                                    final progress = (isCurrent &&
                                            _duration.inMilliseconds > 0)
                                        ? (_position.inMilliseconds /
                                                _duration.inMilliseconds)
                                            .clamp(0.0, 1.0)
                                        : 0.0;

                                    return _buildAudioTile(
                                      context: context,
                                      vm: vm,
                                      item: item,
                                      isSelected: isSelected,
                                      isCurrent: isCurrent,
                                      isPlaying: isPlaying,
                                      progress: progress,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                    if (vm.isSelectionMode)
                      _BottomActionBar(
                        onShare: () {
                          showVortexShareSheet(
                            context,
                            vm.selectedPaths.toList(),
                            onSendStarted: vm.cancelSelection,
                          );
                        },
                        onDelete: vm.selectedPaths.isEmpty
                            ? null
                            : () => _showDeleteDialog(
                                  context,
                                  vm.selectedPaths.length,
                                  vm.deleteSelected,
                                ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAudioTile({
    required BuildContext context,
    required MediaListViewModel vm,
    required MediaFileItem item,
    required bool isSelected,
    required bool isCurrent,
    required bool isPlaying,
    required double progress,
  }) {
    return InkWell(
      onTap: () {
        if (vm.isSelectionMode) {
          vm.toggleSelection(item.file.path);
        } else {
          _toggleAudio(item);
        }
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        if (!vm.isSelectionMode) {
          vm.enterSelectionWith(item.file.path);
        } else {
          vm.toggleSelection(item.file.path);
        }
      },
      splashColor: AppTheme.accentLime.withOpacity(0.06),
      highlightColor: Colors.white.withOpacity(0.03),
      child: Container(
        color: isSelected
            ? AppTheme.accentLime.withOpacity(0.08)
            : (isCurrent
                ? const Color(0xFF101317)
                : Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.nameWithoutExt,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                _ExtBadge(
                  ext: item.ext,
                  color: AppTheme.accentLime,
                ),
                if (vm.isSelectionMode) ...[
                  const SizedBox(width: 12),
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppTheme.accentLime
                        : const Color(0xFF4A525A),
                    size: 22,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            _AudioWaveform(
              item: item,
              isCurrent: isCurrent,
              isPlaying: isPlaying,
              progress: progress,
              animValue: _waveAnimController.value,
              onSeek: (ratio) => _seekAudio(item, ratio),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.sizeLabel} · ${item.dateLabel}',
                  style: const TextStyle(
                    color: Color(0xFF78828A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isCurrent && _duration.inMilliseconds > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: AppTheme.accentLime,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                        style: const TextStyle(
                          color: AppTheme.accentLime,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MediaListViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
            child: const Text(
              'Select all',
              style: TextStyle(
                color: AppTheme.accentLime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (_searching) {
      return AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _searching = false);
            _searchCtrl.clear();
            vm.applySearch('');
          },
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          cursorColor: AppTheme.accentLime,
          cursorWidth: 2,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search audio…',
            hintStyle: TextStyle(color: Color(0xFF78828A)),
            border: InputBorder.none,
          ),
          onChanged: vm.applySearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                vm.applySearch('');
                setState(() {});
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: const Text(
        'Audio',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 22),
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }
}

class DocumentsView extends StatefulWidget {
  const DocumentsView({Key? key}) : super(key: key);

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  static const _exts = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'rtf',
    'odt',
    'ofd',
    'csv',
  };
  static const _filters = ['All', 'PDF', 'DOC', 'XLS', 'PPT', 'TXT'];

  final _searchFocus = FocusNode();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Color _docBadgeColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFFF5C5C);
      case 'doc':
      case 'docx':
        return const Color(0xFF4D9BFF);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return AppTheme.accentLime;
      case 'ppt':
      case 'pptx':
        return const Color(0xFFFF9F43);
      case 'txt':
      case 'rtf':
      case 'odt':
      default:
        return const Color(0xFFA0AAB5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MediaListViewModel(_exts),
      child: Consumer<MediaListViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentLime),
                )
              : Column(
                  children: [
                    if (!vm.isSelectionMode) ...[
                      _PillFilterBar(
                        filters: _filters,
                        active: vm.activeFilter,
                        onSelect: vm.applyFilter,
                      ),
                      _MediaCountHeader(
                        count: vm.filteredItems.length,
                        noun: 'item',
                      ),
                    ],
                    Expanded(
                      child: vm.filteredItems.isEmpty
                          ? _EmptyMediaState(
                              icon: Icons.folder_open_outlined,
                              label: _searching && _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No documents found',
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 30),
                              itemCount: vm.filteredItems.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFF16191E),
                                height: 1,
                                thickness: 1,
                              ),
                              itemBuilder: (context, i) {
                                final item = vm.filteredItems[i];
                                final isSelected = vm.selectedPaths
                                    .contains(item.file.path);
                                final badgeColor = _docBadgeColor(item.ext);

                                return InkWell(
                                  onTap: () {
                                    if (vm.isSelectionMode) {
                                      vm.toggleSelection(item.file.path);
                                    } else {
                                      FileOpener.openFile(
                                          context, item.file.path);
                                    }
                                  },
                                  onLongPress: () {
                                    HapticFeedback.mediumImpact();
                                    if (!vm.isSelectionMode) {
                                      vm.enterSelectionWith(item.file.path);
                                    } else {
                                      vm.toggleSelection(item.file.path);
                                    }
                                  },
                                  splashColor:
                                      badgeColor.withOpacity(0.06),
                                  highlightColor:
                                      Colors.white.withOpacity(0.03),
                                  child: Container(
                                    color: isSelected
                                        ? AppTheme.accentLime.withOpacity(0.08)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.nameWithoutExt,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _ExtBadge(
                                              ext: item.ext,
                                              color: badgeColor,
                                            ),
                                            if (vm.isSelectionMode) ...[
                                              const SizedBox(width: 12),
                                              Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: isSelected
                                                    ? AppTheme.accentLime
                                                    : const Color(0xFF4A525A),
                                                size: 22,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        _DocumentRibbon(
                                          item: item,
                                          accentColor: badgeColor,
                                        ),
                                        const SizedBox(height: 10),

                                        Text(
                                          '${item.sizeLabel} · ${item.dateLabel}',
                                          style: const TextStyle(
                                            color: Color(0xFF78828A),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (vm.isSelectionMode)
                      _BottomActionBar(
                        onShare: () {
                          showVortexShareSheet(
                            context,
                            vm.selectedPaths.toList(),
                            onSendStarted: vm.cancelSelection,
                          );
                        },
                        onDelete: vm.selectedPaths.isEmpty
                            ? null
                            : () => _showDeleteDialog(
                                  context,
                                  vm.selectedPaths.length,
                                  vm.deleteSelected,
                                ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MediaListViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
            child: const Text(
              'Select all',
              style: TextStyle(
                color: AppTheme.accentLime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (_searching) {
      return AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _searching = false);
            _searchCtrl.clear();
            vm.applySearch('');
          },
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          cursorColor: AppTheme.accentLime,
          cursorWidth: 2,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search documents…',
            hintStyle: TextStyle(color: Color(0xFF78828A)),
            border: InputBorder.none,
          ),
          onChanged: vm.applySearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                vm.applySearch('');
                setState(() {});
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: const Text(
        'Documents',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 22),
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }
}

class ArchivesView extends StatefulWidget {
  const ArchivesView({Key? key}) : super(key: key);

  @override
  State<ArchivesView> createState() => _ArchivesViewState();
}

class _ArchivesViewState extends State<ArchivesView> {
  static const _exts = {
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'bz2',
    'xz',
    'jar',
    'iso',
  };
  static const _filters = ['All', 'ZIP', 'RAR', '7Z', 'TAR', 'JAR', 'ISO'];

  final _searchFocus = FocusNode();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Color _archBadgeColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'zip':
        return AppTheme.accentLime;
      case 'rar':
        return const Color(0xFFB57CFF);
      case '7z':
        return const Color(0xFF4D9BFF);
      case 'tar':
      case 'gz':
        return const Color(0xFFFF9F43);
      case 'jar':
        return const Color(0xFF2ED573);
      case 'iso':
      default:
        return const Color(0xFFA0AAB5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MediaListViewModel(_exts),
      child: Consumer<MediaListViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentLime),
                )
              : Column(
                  children: [
                    if (!vm.isSelectionMode) ...[
                      _PillFilterBar(
                        filters: _filters,
                        active: vm.activeFilter,
                        onSelect: vm.applyFilter,
                      ),
                      _MediaCountHeader(
                        count: vm.filteredItems.length,
                        noun: 'item',
                      ),
                    ],
                    Expanded(
                      child: vm.filteredItems.isEmpty
                          ? _EmptyMediaState(
                              icon: Icons.inventory_2_outlined,
                              label: _searching && _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No archives found',
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 30),
                              itemCount: vm.filteredItems.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFF16191E),
                                height: 1,
                                thickness: 1,
                              ),
                              itemBuilder: (context, i) {
                                final item = vm.filteredItems[i];
                                final isSelected = vm.selectedPaths
                                    .contains(item.file.path);
                                final badgeColor = _archBadgeColor(item.ext);

                                return InkWell(
                                  onTap: () {
                                    if (vm.isSelectionMode) {
                                      vm.toggleSelection(item.file.path);
                                    } else {
                                      FileOpener.openFile(
                                          context, item.file.path);
                                    }
                                  },
                                  onLongPress: () {
                                    HapticFeedback.mediumImpact();
                                    if (!vm.isSelectionMode) {
                                      vm.enterSelectionWith(item.file.path);
                                    } else {
                                      vm.toggleSelection(item.file.path);
                                    }
                                  },
                                  splashColor:
                                      badgeColor.withOpacity(0.06),
                                  highlightColor:
                                      Colors.white.withOpacity(0.03),
                                  child: Container(
                                    color: isSelected
                                        ? AppTheme.accentLime.withOpacity(0.08)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.nameWithoutExt,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _ExtBadge(
                                              ext: item.ext,
                                              color: badgeColor,
                                            ),
                                            if (vm.isSelectionMode) ...[
                                              const SizedBox(width: 12),
                                              Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: isSelected
                                                    ? AppTheme.accentLime
                                                    : const Color(0xFF4A525A),
                                                size: 22,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        _ArchiveRibbon(
                                          item: item,
                                          accentColor: badgeColor,
                                        ),
                                        const SizedBox(height: 10),

                                        Text(
                                          '${item.sizeLabel} · ${item.dateLabel}',
                                          style: const TextStyle(
                                            color: Color(0xFF78828A),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (vm.isSelectionMode)
                      _BottomActionBar(
                        onShare: () {
                          showVortexShareSheet(
                            context,
                            vm.selectedPaths.toList(),
                            onSendStarted: vm.cancelSelection,
                          );
                        },
                        onDelete: vm.selectedPaths.isEmpty
                            ? null
                            : () => _showDeleteDialog(
                                  context,
                                  vm.selectedPaths.length,
                                  vm.deleteSelected,
                                ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MediaListViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
            child: const Text(
              'Select all',
              style: TextStyle(
                color: AppTheme.accentLime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (_searching) {
      return AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _searching = false);
            _searchCtrl.clear();
            vm.applySearch('');
          },
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          cursorColor: AppTheme.accentLime,
          cursorWidth: 2,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search archives…',
            hintStyle: TextStyle(color: Color(0xFF78828A)),
            border: InputBorder.none,
          ),
          onChanged: vm.applySearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                vm.applySearch('');
                setState(() {});
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: const Text(
        'Archives',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 22),
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }
}

class ApksView extends StatefulWidget {
  const ApksView({Key? key}) : super(key: key);

  @override
  State<ApksView> createState() => _ApksViewState();
}

class _ApksViewState extends State<ApksView> {
  static const _exts = {'apk', 'aab', 'xapk'};
  final _searchFocus = FocusNode();
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MediaListViewModel(_exts),
      child: Consumer<MediaListViewModel>(
        builder: (context, vm, _) => Scaffold(
          backgroundColor: Colors.black,
          appBar: _buildAppBar(context, vm),
          body: vm.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentLime),
                )
              : Column(
                  children: [
                    if (!vm.isSelectionMode)
                      _MediaCountHeader(
                        count: vm.filteredItems.length,
                        noun: 'APK file',
                      ),
                    Expanded(
                      child: vm.filteredItems.isEmpty
                          ? _EmptyMediaState(
                              icon: Icons.android_outlined,
                              label: _searching && _searchCtrl.text.isNotEmpty
                                  ? 'No results for "${_searchCtrl.text}"'
                                  : 'No APK files found',
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 30),
                              itemCount: vm.filteredItems.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFF16191E),
                                height: 1,
                                thickness: 1,
                              ),
                              itemBuilder: (context, i) {
                                final item = vm.filteredItems[i];
                                final isSelected = vm.selectedPaths
                                    .contains(item.file.path);

                                return InkWell(
                                  onTap: () {
                                    if (vm.isSelectionMode) {
                                      vm.toggleSelection(item.file.path);
                                    } else {
                                      FileOpener.openFile(
                                          context, item.file.path);
                                    }
                                  },
                                  onLongPress: () {
                                    HapticFeedback.mediumImpact();
                                    if (!vm.isSelectionMode) {
                                      vm.enterSelectionWith(item.file.path);
                                    } else {
                                      vm.toggleSelection(item.file.path);
                                    }
                                  },
                                  splashColor:
                                      AppTheme.accentLime.withOpacity(0.06),
                                  highlightColor:
                                      Colors.white.withOpacity(0.03),
                                  child: Container(
                                    color: isSelected
                                        ? AppTheme.accentLime.withOpacity(0.08)
                                        : Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.nameWithoutExt,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _ExtBadge(
                                              ext: item.ext,
                                              color: AppTheme.accentLime,
                                            ),
                                            if (vm.isSelectionMode) ...[
                                              const SizedBox(width: 12),
                                              Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: isSelected
                                                    ? AppTheme.accentLime
                                                    : const Color(0xFF4A525A),
                                                size: 22,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        _ApkRibbon(item: item),
                                        const SizedBox(height: 10),

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${item.sizeLabel} · ${item.dateLabel}',
                                              style: const TextStyle(
                                                color: Color(0xFF78828A),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (!vm.isSelectionMode)
                                              GestureDetector(
                                                onTap: () =>
                                                    FileOpener.openFile(
                                                        context,
                                                        item.file.path),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.accentLime
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: AppTheme.accentLime
                                                          .withOpacity(0.4),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    'INSTALL',
                                                    style: TextStyle(
                                                      color:
                                                          AppTheme.accentLime,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (vm.isSelectionMode)
                      _BottomActionBar(
                        onShare: () {
                          showVortexShareSheet(
                            context,
                            vm.selectedPaths.toList(),
                            onSendStarted: vm.cancelSelection,
                          );
                        },
                        onDelete: vm.selectedPaths.isEmpty
                            ? null
                            : () => _showDeleteDialog(
                                  context,
                                  vm.selectedPaths.length,
                                  vm.deleteSelected,
                                ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    MediaListViewModel vm,
  ) {
    if (vm.isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: vm.cancelSelection,
        ),
        title: Text(
          '${vm.selectedPaths.length} selected',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.selectAll,
            child: const Text(
              'Select all',
              style: TextStyle(
                color: AppTheme.accentLime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    if (_searching) {
      return AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            setState(() => _searching = false);
            _searchCtrl.clear();
            vm.applySearch('');
          },
        ),
        title: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          autofocus: true,
          cursorColor: AppTheme.accentLime,
          cursorWidth: 2,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search APKs…',
            hintStyle: TextStyle(color: Color(0xFF78828A)),
            border: InputBorder.none,
          ),
          onChanged: vm.applySearch,
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () {
                _searchCtrl.clear();
                vm.applySearch('');
                setState(() {});
              },
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: const Text(
        'APKs',
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 22),
          onPressed: () => setState(() => _searching = true),
        ),
      ],
    );
  }
}

/// Exact match for Filter Pills bar in screenshot
class _PillFilterBar extends StatelessWidget {
  final List<String> filters;
  final String active;
  final void Function(String) onSelect;

  const _PillFilterBar({
    required this.filters,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final f = filters[i];
          final isSelected = f == active ||
              (active != 'All' && f.toLowerCase() == active.toLowerCase());

          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 20 : 16,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentLime
                    : const Color(0xFF14171B),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentLime
                      : const Color(0xFF242A32),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                f,
                style: TextStyle(
                  color: isSelected ? Colors.black : const Color(0xFFD6DCE2),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Exact match for Counter header (e.g. "1 item" + divider line)
class _MediaCountHeader extends StatelessWidget {
  final int count;
  final String noun;

  const _MediaCountHeader({
    required this.count,
    this.noun = 'item',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text(
            '$count $noun${count == 1 ? '' : (noun.endsWith('file') ? 's' : 's')}',
            style: const TextStyle(
              color: Color(0xFF78828A),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Divider(color: Color(0xFF1E2228), height: 1, thickness: 1),
      ],
    );
  }
}

/// Exact match for Extension badge (e.g. [FLAC], [MP3], [PDF])
class _ExtBadge extends StatelessWidget {
  final String ext;
  final Color color;

  const _ExtBadge({
    required this.ext,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF14171B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.55),
          width: 1.0,
        ),
      ),
      child: Text(
        ext.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Exact Waveform visual with dynamic playback and interactive seeking
class _AudioWaveform extends StatelessWidget {
  final MediaFileItem item;
  final bool isCurrent;
  final bool isPlaying;
  final double progress;
  final double animValue;
  final void Function(double ratio) onSeek;

  const _AudioWaveform({
    Key? key,
    required this.item,
    required this.isCurrent,
    required this.isPlaying,
    required this.progress,
    required this.animValue,
    required this.onSeek,
  }) : super(key: key);

  static final Map<String, List<double>> _heightCache = {};

  static List<double> _getWaveHeights(String path, int count) {
    final key = '$path-$count';
    if (_heightCache.containsKey(key)) return _heightCache[key]!;

    final rand = math.Random(path.hashCode.abs());
    final list = <double>[];
    double current = 0.45;
    for (int i = 0; i < count; i++) {
      final t = i / count.toDouble();
      final envelope = math.sin(t * math.pi) * 0.7 + 0.3;
      final jitter = (rand.nextDouble() - 0.5) * 0.6;
      current = (current + jitter).clamp(0.18, 1.0);
      list.add((current * envelope).clamp(0.18, 1.0));
    }
    _heightCache[key] = list;
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final count = (totalWidth / 5.2).floor().clamp(35, 60);
        final barWidth = 2.5;
        final heights = _getWaveHeights(item.file.path, count);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final x = details.localPosition.dx.clamp(0.0, totalWidth);
            final ratio = (x / totalWidth).clamp(0.0, 1.0);
            onSeek(ratio);
          },
          onHorizontalDragUpdate: (details) {
            final x = details.localPosition.dx.clamp(0.0, totalWidth);
            final ratio = (x / totalWidth).clamp(0.0, 1.0);
            onSeek(ratio);
          },
          child: Container(
            height: 28,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(count, (i) {
                final barRatio = i / (count - 1).toDouble();
                final isPassed = isCurrent && (barRatio <= progress);
                double h = heights[i] * 24.0;

                if (isCurrent && isPlaying) {
                  final dist = (barRatio - progress).abs();
                  if (dist < 0.15) {
                    final flutter =
                        (math.sin((animValue * math.pi * 2) + i) * 4.0);
                    h = (h + flutter).clamp(4.0, 26.0);
                  }
                }

                final color = isPassed
                    ? AppTheme.accentLime
                    : const Color(0xFF262C34);

                return Container(
                  width: barWidth,
                  height: h.clamp(4.0, 26.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
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

/// Sleek Document visual ribbon (Page lines + Folder tag)
class _DocumentRibbon extends StatelessWidget {
  final MediaFileItem item;
  final Color accentColor;

  const _DocumentRibbon({
    required this.item,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final folderName = item.file.parent.path.split('/').last;

        return Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.ext.toLowerCase() == 'pdf'
                        ? Icons.picture_as_pdf
                        : Icons.description_outlined,
                    size: 12,
                    color: accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    folderName.isNotEmpty ? folderName : 'Root',
                    style: TextStyle(
                      color: accentColor.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DocLineTrack(seed: item.file.path.hashCode),
            ),
          ],
        );
      },
    );
  }
}

class _DocLineTrack extends StatelessWidget {
  final int seed;

  const _DocLineTrack({required this.seed});

  @override
  Widget build(BuildContext context) {
    final rand = math.Random(seed.abs());
    return Row(
      children: List.generate(4, (i) {
        final flex = (rand.nextInt(3) + 2);
        return Expanded(
          flex: flex,
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF262C34),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      }),
    );
  }
}

/// Sleek Archive compression blocks ribbon (Zipper tooth pattern)
class _ArchiveRibbon extends StatelessWidget {
  final MediaFileItem item;
  final Color accentColor;

  const _ArchiveRibbon({
    required this.item,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final folderName = item.file.parent.path.split('/').last;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_zip_outlined,
                size: 12,
                color: accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                folderName.isNotEmpty ? folderName : 'Root',
                style: TextStyle(
                  color: accentColor.withOpacity(0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(24, (i) {
                return Container(
                  width: 2.5,
                  height: i % 2 == 0 ? 8 : 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262C34),
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sleek APK ribbon
class _ApkRibbon extends StatelessWidget {
  final MediaFileItem item;

  const _ApkRibbon({required this.item});

  @override
  Widget build(BuildContext context) {
    final folderName = item.file.parent.path.split('/').last;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.accentLime.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.android,
                size: 12,
                color: AppTheme.accentLime,
              ),
              SizedBox(width: 4),
              Text(
                'Package',
                style: TextStyle(
                  color: AppTheme.accentLime,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            folderName.isNotEmpty ? folderName : 'Internal storage',
            style: const TextStyle(
              color: Color(0xFF5A626A),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Empty state widget
class _EmptyMediaState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyMediaState({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: const Color(0xFF2E333B)),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78828A),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Bottom action bar in selection mode
class _BottomActionBar extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback? onDelete;

  const _BottomActionBar({
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF101317),
        border: Border(top: BorderSide(color: Color(0xFF1E2228))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppTheme.accentLime,
            onTap: onShare,
          ),
          Container(width: 1, height: 32, color: const Color(0xFF242A32)),
          _ActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: Colors.redAccent,
            onTap: onDelete ?? () {},
            enabled: onDelete != null,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool enabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = enabled ? color : color.withOpacity(0.35);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDeleteDialog(
  BuildContext context,
  int count,
  VoidCallback onConfirm,
) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF14171B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Permanently delete $count item(s)?',
        style: const TextStyle(color: Color(0xFF78828A), fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF78828A)),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child: const Text(
            'Delete',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
