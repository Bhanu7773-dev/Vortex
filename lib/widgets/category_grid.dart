import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/category_model.dart';
import '../theme/app_theme.dart';
import '../views/photos_view.dart';
import '../views/videos_view.dart';
import '../views/media_list_views.dart';

class CategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;

  const CategoryGrid({Key? key, required this.categories}) : super(key: key);

  void _onCategoryTap(BuildContext context, CategoryModel category) {
    switch (category.name) {
      case 'Photos':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PhotosView()),
        );
        break;
      case 'Videos':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VideosView()),
        );
        break;
      case 'Audio':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AudioView()),
        );
        break;
      case 'Archives':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArchivesView()),
        );
        break;
      case 'APKs':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ApksView()),
        );
        break;
      case 'Documents':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DocumentsView()),
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return GestureDetector(
          onTap: () => _onCategoryTap(context, category),
          child: _CategoryCard(category: category)
              .animate()
              .fade(duration: 400.ms, delay: (50 * index).ms)
              .slideY(
                begin: 0.2,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutQuad,
              ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.iconColor.withOpacity(0.2),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.iconColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  category.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.info,
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (category.badgeCount > 0)
            Positioned(
              top: 12,
              right: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  category.badgeCount > 9
                      ? '9+'
                      : category.badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
