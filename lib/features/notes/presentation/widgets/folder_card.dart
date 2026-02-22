import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/folder_model.dart';

class FolderCard extends StatelessWidget {
  final FolderModel folder;

  const FolderCard({super.key, required this.folder});

  Color _getFolderColor() {
    if (folder.color == null) {
      return AppColors.primary.withValues(alpha: 0.1);
    }
    try {
      final colorStr = folder.color!.replaceAll('#', '');
      return Color(int.parse('0xff$colorStr'));
    } catch (_) {
      return AppColors.primary.withValues(alpha: 0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getFolderColor(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            Icons.folder_rounded, 
            color: folder.color != null ? Colors.white : AppColors.primary,
            size: 32
          ),
          Text(
            folder.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: folder.color != null ? Colors.white : AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
