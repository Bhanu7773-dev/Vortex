import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TagSelectionSheet extends StatefulWidget {
  final Function(String) onTagSelected;

  const TagSelectionSheet({Key? key, required this.onTagSelected})
    : super(key: key);

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
        title: const Text('New Tag'),
        content: TextField(
          controller: _customCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter tag name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_customCtrl.text.trim().isNotEmpty) {
                widget.onTagSelected(_customCtrl.text.trim());
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Sheet
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: AppTheme.cardGrey,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Tag',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ..._defaultTags.map(
                (tag) => ActionChip(
                  label: Text(tag),
                  backgroundColor: Colors.white10,
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () {
                    widget.onTagSelected(tag);
                    Navigator.pop(context);
                  },
                ),
              ),
              ActionChip(
                label: const Text('+ Custom'),
                backgroundColor: AppTheme.accentBlue.withOpacity(0.2),
                labelStyle: const TextStyle(color: AppTheme.accentBlue),
                onPressed: _showCustomTagDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
