import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/storage_card.dart';
import '../widgets/category_grid.dart';
import '../widgets/expandable_list.dart';
import '../theme/app_theme.dart';

class HomeView extends StatelessWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => HomeViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Files'),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                        title: const Text(
                          'Recently deleted',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        subtitle: const Text(
                          '27 items | 204 MB',
                          style: TextStyle(
                            color: AppTheme.textGrey,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Container(
                          decoration: const BoxDecoration(
                            color: AppTheme.accentBlue,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.cleaning_services,
                              color: Colors.white,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ),
                  ),
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
