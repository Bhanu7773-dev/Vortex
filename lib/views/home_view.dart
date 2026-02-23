import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/storage_card.dart';
import '../widgets/category_grid.dart';
import '../widgets/expandable_list.dart';

class HomeView extends StatelessWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => HomeViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vortex'),
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          ],
        ),
        body: Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isPermissionDenied) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.security_outlined,
                        size: 80,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Permission Required',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Vortex needs storage access to show your files. Please grant permission in settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => viewModel.checkAndRequestPermissions(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Grant Permission'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                if (!viewModel.hasFullAccess)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orangeAccent,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Limited Access Detected',
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Android 11+ requires "All Files Access" to manage archives, APKs, and documents. Currently, only media folders may be visible.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () =>
                                viewModel.checkAndRequestPermissions(),
                            child: const Text('Enable All Files Access'),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: StorageCard(
                    totalStorage: viewModel.totalStorage,
                    usedStorage: viewModel.usedStorage,
                    percentage: viewModel.storagePercentage,
                  ),
                ),
                SliverToBoxAdapter(
                  child: CategoryGrid(categories: viewModel.categories),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return ExpandableSection(
                      section: viewModel.sections[index],
                    );
                  }, childCount: viewModel.sections.length),
                ),
                // Padding for FAB area
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
      ),
    );
  }
}
