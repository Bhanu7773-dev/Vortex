import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TagSelectionSheet extends StatefulWidget {
  final Function(String) onTagSelected;

  const TagSelectionSheet({super.key, required this.onTagSelected});

  @override
  State<TagSelectionSheet> createState() => _TagSelectionSheetState();
}

class _TagSelectionSheetState extends State<TagSelectionSheet> {
  final List<String> _defaultTags = ['Important', 'Work', 'Study', 'Life'];
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _showCustomTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161917),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF262A28), width: 1),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22),
        actionsPadding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
        title: Row(
          children: [
            const Icon(Icons.bookmark_add_outlined, color: AppTheme.accentLime, size: 24),
            const SizedBox(width: 12),
            Text(
              'New tag',
              style: TextStyle(
                fontFamily: AppTheme.fontBricolage,
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1210),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262A28), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _customCtrl,
            autofocus: true,
            cursorColor: AppTheme.accentLime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter tag name',
              hintStyle: TextStyle(color: Color(0xFF78828A), fontSize: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF78828A),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_customCtrl.text.trim().isNotEmpty) {
                widget.onTagSelected(_customCtrl.text.trim());
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentLime,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF141715),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF262A28), width: 1),
          left: BorderSide(color: Color(0xFF262A28), width: 1),
          right: BorderSide(color: Color(0xFF262A28), width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3F3D),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.bookmark_border_rounded, color: AppTheme.accentLime, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Select tag',
                  style: TextStyle(
                    fontFamily: AppTheme.fontBricolage,
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._defaultTags.map(
                  (tag) => ActionChip(
                    label: Text(tag),
                    backgroundColor: const Color(0xFF1E2220),
                    side: const BorderSide(color: Color(0xFF262A28), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    onPressed: () {
                      widget.onTagSelected(tag);
                      Navigator.pop(context);
                    },
                  ),
                ),
                ActionChip(
                  label: const Text('+ Custom'),
                  backgroundColor: AppTheme.accentLime.withOpacity(0.12),
                  side: BorderSide(
                    color: AppTheme.accentLime.withOpacity(0.4),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelStyle: const TextStyle(
                    color: AppTheme.accentLime,
                    fontWeight: FontWeight.w700,
                  ),
                  onPressed: _showCustomTagDialog,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
