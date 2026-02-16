import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/custom_tag.dart';
import '../services/tag_service.dart';
import '../services/focus_service.dart';

class CustomTagsScreen extends StatefulWidget {
  const CustomTagsScreen({super.key});

  @override
  State<CustomTagsScreen> createState() => _CustomTagsScreenState();
}

class _CustomTagsScreenState extends State<CustomTagsScreen> {
  final TagService _tagService = TagService();
  final FocusService _focusService = FocusService();

  @override
  void initState() {
    super.initState();
    _tagService.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _tagService,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildTagStats(),
                      const SizedBox(height: 24),
                      _buildTagsSection('Default Tags', _tagService.defaultTags),
                      const SizedBox(height: 24),
                      _buildTagsSection('Custom Tags', _tagService.customTags),
                      const SizedBox(height: 24),
                      _buildTagStatistics(),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTagDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Create Tag', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
      ),
      title: const Text(
        'Focus Tags',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTagStats() {
    final tags = _tagService.tags;
    final customCount = _tagService.customTags.length;
    final totalUsage = tags.fold(0, (sum, t) => sum + t.usageCount);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF9C27B0),
            Color(0xFF7B1FA2),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('🏷️', '${tags.length}', 'Total Tags'),
          Container(width: 1, height: 50, color: Colors.white24),
          _buildStatItem('✨', '$customCount', 'Custom'),
          Container(width: 1, height: 50, color: Colors.white24),
          _buildStatItem('📊', '$totalUsage', 'Total Uses'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(String title, List<FocusTag> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${tags.length} tags',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (tags.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                title == 'Custom Tags' 
                    ? 'Create your first custom tag!'
                    : 'No tags available',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: tags.map((tag) => _buildTagChip(tag)).toList(),
          ),
      ],
    );
  }

  Widget _buildTagChip(FocusTag tag) {
    return GestureDetector(
      onTap: () => _showTagDetails(tag),
      onLongPress: tag.isDefault ? null : () => _showDeleteConfirmation(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tag.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tag.color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tag.emoji != null) ...[
              Text(tag.emoji!, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
            ],
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tag.color,
              ),
            ),
            if (tag.usageCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tag.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tag.usageCount}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tag.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagStatistics() {
    final stats = _tagService.calculateTagStatistics(_focusService.sessions);
    
    if (stats.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tag Usage Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...stats.take(5).map((stat) {
            final maxMins = stats.first.totalMinutes;
            final percentage = maxMins > 0 ? stat.totalMinutes / maxMins : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: stat.tagColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            _tagService.getTagById(stat.tagId)?.emoji ?? '🏷️',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.tagName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${stat.sessionCount} sessions',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${stat.totalHours}h ${stat.totalMinutes % 60}m',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: stat.tagColor,
                            ),
                          ),
                          Text(
                            'avg ${stat.averageSessionMinutes.toStringAsFixed(0)}m',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation(stat.tagColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showCreateTagDialog() {
    final nameController = TextEditingController();
    Color selectedColor = FocusTag.availableColors.first;
    String? selectedEmoji;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create Custom Tag',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Tag Name',
                  hintText: 'e.g., Deep Work',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Color',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: FocusTag.availableColors.map((color) {
                  final isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedColor = color),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Emoji (Optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: FocusTag.availableEmojis.map((emoji) {
                  final isSelected = selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setModalState(() {
                      selectedEmoji = isSelected ? null : emoji;
                    }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor.withOpacity(0.2)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: selectedColor, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;
                    
                    await _tagService.createTag(
                      name: nameController.text,
                      colorValue: selectedColor.value,
                      emoji: selectedEmoji,
                    );
                    
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Create Tag',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagDetails(FocusTag tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tag.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  tag.emoji ?? '🏷️',
                  style: const TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: tag.color,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${tag.usageCount}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: tag.color,
                      ),
                    ),
                    const Text(
                      'Times Used',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      tag.isDefault ? 'Default' : 'Custom',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tag.color,
                      ),
                    ),
                    const Text(
                      'Type',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(FocusTag tag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Tag?'),
        content: Text('Are you sure you want to delete "${tag.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _tagService.deleteTag(tag.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
