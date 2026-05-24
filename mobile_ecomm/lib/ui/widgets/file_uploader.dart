import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/alert_service.dart';

/// File Uploader Widget
/// Matches Next.js client FileUploader component
/// Supports image and PDF uploads
class FileUploader extends StatefulWidget {
  final String label;
  final String? accept;
  final File? value;
  final ValueChanged<File?> onUpload;

  const FileUploader({
    super.key,
    this.label = 'Upload File',
    this.accept,
    this.value,
    required this.onUpload,
  });

  @override
  State<FileUploader> createState() => _FileUploaderState();
}

class _FileUploaderState extends State<FileUploader> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (picked != null) {
        widget.onUpload(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to pick image: $e',
          variant: AlertVariant.error,
        );
      }
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            if (widget.value != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onUpload(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  bool get _isImage {
    if (widget.value == null) return false;
    final path = widget.value!.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp');
  }

  String get _fileName {
    if (widget.value == null) return '';
    return widget.value!.path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: _showPickerOptions,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.value != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: widget.value != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: widget.value != null
            ? _buildFilePreview()
            : _buildUploadPrompt(),
      ),
    );
  }

  Widget _buildUploadPrompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(
          widget.label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Tap to upload',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildFilePreview() {
    return Row(
      children: [
        if (_isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              widget.value!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.insert_drive_file,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fileName,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to change',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => widget.onUpload(null),
          icon: const Icon(Icons.close),
          color: Colors.red,
        ),
      ],
    );
  }
}
