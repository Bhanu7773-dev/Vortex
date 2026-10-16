import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vortex/models/recent_model.dart';
import 'package:vortex/theme/app_theme.dart';
import 'package:vortex/utils/file_opener.dart';
import 'package:vortex/viewmodels/recent_viewmodel.dart';
import 'package:vortex/views/all_files_view.dart';
import 'package:vortex/widgets/share_sheet.dart';

class RecentView extends StatelessWidget {
  const RecentView({Key? key}) : super(key: key);

  String _getExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      final ext = parts.last.toUpperCase();
      return ext.length > 4 ? ext.substring(0, 4) : ext;
    }
    return 'FILE';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecentViewModel>(
      create: (_) => RecentViewModel(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<RecentViewModel>(
          builder: (context, viewModel, child) {
            final totalCount = viewModel.sections.fold<int>(
              0,
              (sum, s) => sum + s.files.length,
            );

            return SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Received',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontBricolage,
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$totalCount file${totalCount == 1 ? '' : 's'} received',
                                style: const TextStyle(
                                  color: Color(0xFF78828A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.folder_outlined,
                              color: Colors.white70,
                              size: 24,
                            ),
                            tooltip: 'Open Vortex folder',
                            onPressed: viewModel.receiveDirPath.isEmpty
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AllFilesView(
                                          initialPath: viewModel.receiveDirPath,
                                        ),
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (viewModel.isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accentLime,
                        ),
                      ),
                    )
                  else if (viewModel.sections.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.inbox_outlined,
                                    size: 32,
                                    color: Color(0xFF78828A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'No received files yet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Files received via Vortex or Web Share will appear here',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF78828A),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...viewModel.sections.map((section) {
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  section.title,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontBricolage,
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  '${section.files.length}',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontBricolage,
                                    color: const Color(0xFF78828A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: const Color(0xFF16191E),
                            ),
                            const SizedBox(height: 6),
                            ...section.files.map(
                              (file) => _buildFileRow(context, file),
                            ),
                          ]),
                        ),
                      );
                    }),

                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFileRow(BuildContext context, RecentFileModel file) {
    final ext = _getExtension(file.name);

    return InkWell(
      onTap: () => FileOpener.openFile(context, file.path),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF161E14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.accentLime.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  ext,
                  style: const TextStyle(
                    color: AppTheme.accentLime,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    file.size,
                    style: const TextStyle(
                      color: Color(0xFF78828A),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.file_upload_outlined,
                color: Color(0xFF78828A),
                size: 21,
              ),
              tooltip: 'Share file',
              onPressed: () => showVortexShareSheet(context, [file.path]),
            ),
          ],
        ),
      ),
    );
  }
}
