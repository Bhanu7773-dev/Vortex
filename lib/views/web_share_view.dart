import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vortex/services/web_share_service.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/utils/file_opener.dart';
import 'package:vortex/views/all_files_view.dart';

class WebShareView extends StatelessWidget {
  const WebShareView({super.key});

  static const Color creamCardBg = Color(0xFFEFF2E7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<WebShareService>(
        builder: (context, webShare, _) {
          final url = webShare.webPortalUrl;
          final hostPort = _parseHostPort(url);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: creamCardBg,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(36),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.black,
                                  size: 24,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Web share',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontBricolage,
                                  color: Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const Spacer(),
                              _buildCustomSwitch(
                                isEnabled: webShare.isEnabled,
                                onChanged: (val) =>
                                    webShare.toggleWebShare(val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 250),
                              opacity: webShare.isEnabled ? 1.0 : 0.25,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: QrImageView(
                                  data: url.isNotEmpty
                                      ? url
                                      : 'http://127.0.0.1:${webShare.port}/',
                                  version: QrVersions.auto,
                                  size: 215.0,
                                  backgroundColor: Colors.transparent,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          const Text(
                            'Open this address on any device',
                            style: TextStyle(
                              color: Color(0xFF78828A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: RichText(
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: hostPort.$1,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontBricolage,
                                      color: Colors.black,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                  TextSpan(
                                    text: hostPort.$2,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontBricolage,
                                      color:
                                          Colors.black.withValues(alpha: 0.45),
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPillButton(
                                icon: Icons.copy_rounded,
                                label: 'Copy link',
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: url));
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: const [
                                          Icon(
                                            Icons.check_circle_outline_rounded,
                                            color: AppTheme.accentLime,
                                            size: 20,
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Portal link copied to clipboard',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: const Color(0xFF16191D),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(
                                          color: Color(0xFF262A28),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildPillButton(
                                icon: Icons.refresh_rounded,
                                label: 'New link',
                                onTap: () async {
                                  await webShare.generateNewLink();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.refresh_rounded,
                                            color: AppTheme.accentLime,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'New link generated (port ${webShare.port})',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: const Color(0xFF16191D),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(
                                          color: Color(0xFF262A28),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: webShare.isEnabled
                                  ? AppTheme.accentLime
                                  : const Color(0xFF78828A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              webShare.isEnabled
                                  ? 'Live. Works offline on local Wi-Fi or hotspot.'
                                  : 'Paused. Turn on Web share to start portal.',
                              style: const TextStyle(
                                color: Color(0xFF8E959E),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Staged files',
                            style: TextStyle(
                              fontFamily: AppTheme.fontBricolage,
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            '${webShare.sharedFiles.length}',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontBricolage,
                              color: Color(0xFF8E959E),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (webShare.sharedFiles.isEmpty)
                        const Text(
                          'Nothing staged. Pick files in Vortex or tap Add files and they become downloadable from the browser.',
                          style: TextStyle(
                            color: Color(0xFF8E959E),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: webShare.sharedFiles.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = webShare.sharedFiles[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14171B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file_outlined,
                                    color: AppTheme.accentLime,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          item.sizeFormatted,
                                          style: const TextStyle(
                                            color: Color(0xFF8E959E),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Color(0xFF8E959E),
                                      size: 18,
                                    ),
                                    onPressed: () => webShare.removeFile(index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      if (webShare.receivedFromWeb.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Received from Browser',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: webShare.receivedFromWeb.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = webShare.receivedFromWeb[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14171B),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.download_done_rounded,
                                    color: AppTheme.accentLime,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => FileOpener.openFile(
                                        context, item.path),
                                    child: const Text(
                                      'Open',
                                      style: TextStyle(
                                        color: AppTheme.accentLime,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 28),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepColumn(
                            number: '1',
                            text: 'Join the same\nWi-Fi or hotspot',
                          ),
                          const SizedBox(width: 12),
                          _buildStepColumn(
                            number: '2',
                            text: 'Scan the code\nor type the link',
                          ),
                          const SizedBox(width: 12),
                          _buildStepColumn(
                            number: '3',
                            text: 'Download, or\ndrop files to\nupload',
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      GestureDetector(
                        onTap: () async {
                          final selected = await Navigator.push<List<String>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AllFilesView(
                                isFilePickerMode: true,
                              ),
                            ),
                          );
                          if (selected != null && selected.isNotEmpty) {
                            webShare.addFiles(selected);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: AppTheme.accentLime,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${selected.length} file${selected.length == 1 ? '' : 's'} staged for Web share',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF16191D),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFF262A28),
                                    width: 1,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppTheme.accentLime,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add,
                                color: Colors.black,
                                size: 22,
                                weight: 700,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add files',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static (String, String) _parseHostPort(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
      final port = uri.hasPort ? ':${uri.port}' : '';
      return (host, port);
    } catch (_) {
      return (url, '');
    }
  }

  Widget _buildCustomSwitch({
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!isEnabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFF14171A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppTheme.accentLime
                  : const Color(0xFF78828A),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.black,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepColumn({
    required String number,
    required String text,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              color: AppTheme.accentLime,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFB0B7C0),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
