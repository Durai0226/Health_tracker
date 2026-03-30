import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/mood_theme.dart';

/// Photo gallery widget for mood entries
/// Displays photos in a grid and allows adding/removing
class MoodPhotoGallery extends StatelessWidget {
  final List<String> photos;
  final ValueChanged<List<String>> onPhotosChanged;
  final bool editable;
  final int maxPhotos;

  const MoodPhotoGallery({
    super.key,
    required this.photos,
    required this.onPhotosChanged,
    this.editable = true,
    this.maxPhotos = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editable || photos.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.photo_library_rounded,
                size: 18,
                color: MoodTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Photos',
                style: MoodTheme.bodyMd.copyWith(
                  color: MoodTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (editable && photos.length < maxPhotos)
                TextButton.icon(
                  onPressed: () => _showPhotoOptions(context),
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: const Text('Add'),
                  style: TextButton.styleFrom(
                    foregroundColor: MoodTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (photos.isNotEmpty)
          _buildPhotoGrid(context)
        else if (editable)
          _buildEmptyState(context),
      ],
    );
  }

  Widget _buildPhotoGrid(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + (editable && photos.length < maxPhotos ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return _buildAddPhotoButton(context);
          }
          return _buildPhotoTile(context, photos[index], index);
        },
      ),
    );
  }

  Widget _buildPhotoTile(BuildContext context, String photoPath, int index) {
    final isLocalFile = photoPath.startsWith('/') || photoPath.startsWith('file://');
    
    return GestureDetector(
      onTap: () => _viewPhoto(context, photoPath),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: MoodTheme.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isLocalFile
                  ? Image.file(
                      File(photoPath.replaceFirst('file://', '')),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
                    )
                  : Image.network(
                      photoPath,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: MoodTheme.backgroundSecondary,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: MoodTheme.primary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => _buildErrorPlaceholder(),
                    ),
            ),
          ),
          if (editable)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final newPhotos = List<String>.from(photos)..removeAt(index);
                  onPhotosChanged(newPhotos);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: MoodTheme.backgroundSecondary,
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: MoodTheme.textMuted,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildAddPhotoButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPhotoOptions(context),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: MoodTheme.primarySoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MoodTheme.primary.withOpacity(0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              color: MoodTheme.primary,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: MoodTheme.bodySm.copyWith(
                color: MoodTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPhotoOptions(context),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: MoodTheme.primarySoft.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MoodTheme.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_rounded,
              color: MoodTheme.primary.withOpacity(0.7),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Add photos to capture this moment',
              style: MoodTheme.bodyMd.copyWith(
                color: MoodTheme.primary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: MoodTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MoodTheme.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Photo',
              style: MoodTheme.headingSm.copyWith(
                color: MoodTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOptionButton(
                  context,
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => _pickImage(context, ImageSource.camera),
                ),
                _buildPhotoOptionButton(
                  context,
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => _pickImage(context, ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: MoodTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: MoodTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: MoodTheme.bodySm.copyWith(
              color: MoodTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    Navigator.pop(context);
    
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        HapticFeedback.mediumImpact();
        final newPhotos = List<String>.from(photos)..add(image.path);
        onPhotosChanged(newPhotos);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _viewPhoto(BuildContext context, String photoPath) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PhotoViewScreen(photoPath: photoPath),
      ),
    );
  }
}

/// Full screen photo viewer
class _PhotoViewScreen extends StatelessWidget {
  final String photoPath;

  const _PhotoViewScreen({required this.photoPath});

  @override
  Widget build(BuildContext context) {
    final isLocalFile = photoPath.startsWith('/') || photoPath.startsWith('file://');
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: isLocalFile
              ? Image.file(
                  File(photoPath.replaceFirst('file://', '')),
                  fit: BoxFit.contain,
                )
              : Image.network(
                  photoPath,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: MoodTheme.primary,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Compact photo preview for mood entry cards
class MoodPhotoPreview extends StatelessWidget {
  final List<String> photos;
  final double size;
  final int maxVisible;

  const MoodPhotoPreview({
    super.key,
    required this.photos,
    this.size = 40,
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    
    final visiblePhotos = photos.take(maxVisible).toList();
    final remaining = photos.length - maxVisible;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visiblePhotos.asMap().entries.map((entry) {
          final index = entry.key;
          final photoPath = entry.value;
          final isLocalFile = photoPath.startsWith('/') || photoPath.startsWith('file://');
          
          return Transform.translate(
            offset: Offset(-index * 12.0, 0),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size / 4),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size / 4 - 2),
                child: isLocalFile
                    ? Image.file(
                        File(photoPath.replaceFirst('file://', '')),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: MoodTheme.backgroundSecondary,
                          child: const Icon(Icons.image, size: 16),
                        ),
                      )
                    : Image.network(
                        photoPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: MoodTheme.backgroundSecondary,
                          child: const Icon(Icons.image, size: 16),
                        ),
                      ),
              ),
            ),
          );
        }),
        if (remaining > 0)
          Transform.translate(
            offset: Offset(-visiblePhotos.length * 12.0, 0),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: MoodTheme.primary,
                borderRadius: BorderRadius.circular(size / 4),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size / 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
