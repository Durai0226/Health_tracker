import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/tag_model.dart';
import '../../data/repositories/notes_repository.dart';

class TagManagementDialog extends StatefulWidget {
  const TagManagementDialog({super.key});

  @override
  State<TagManagementDialog> createState() => _TagManagementDialogState();
}

class _TagManagementDialogState extends State<TagManagementDialog> {
  final NotesRepository _repository = NotesRepository();
  List<TagModel> _tags = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  void _loadTags() {
    setState(() {
      _tags = _repository.getAllTags();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Manage Tags"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "New Tag",
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) => _buildTagChip(tag)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Done"),
        ),
      ],
    );
  }

  Widget _buildTagChip(TagModel tag) {
    return Chip(
      label: Text(tag.name),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () => _deleteTag(tag.id),
      backgroundColor: AppColors.background,
      side: BorderSide(color: AppColors.divider),
    );
  }

  Future<void> _addTag() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      await _repository.createTag(name);
      _controller.clear();
      _loadTags();
    }
  }

  Future<void> _deleteTag(String id) async {
    await _repository.deleteTag(id);
    _loadTags();
  }
}
