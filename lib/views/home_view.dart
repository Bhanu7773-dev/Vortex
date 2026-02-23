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
            return CustomScrollView(
              slivers: [
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
