import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_inference_api.dart';
import '../utils/theme.dart';

class BeeImageUploadZone extends StatefulWidget {
  final ValueChanged<XFile> onSelected;
  final bool enabled;
  const BeeImageUploadZone({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });
  @override
  State<BeeImageUploadZone> createState() => _BeeImageUploadZoneState();
}

class _BeeImageUploadZoneState extends State<BeeImageUploadZone> {
  bool _hover = false;
  bool _reading = false;
  String? _error;
  Future<void> _accept(XFile file) async {
    if (!widget.enabled || _reading) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      await ImageInferenceApi.validateImage(file);
      if (mounted && widget.enabled) widget.onSelected(file);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ImageInferenceException
              ? error.message
              : 'Could not read this image. Try another file.',
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _browse() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file != null) await _accept(file);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open files. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => DropTarget(
    enable: widget.enabled && !_reading,
    onDragEntered: (_) => setState(() => _hover = true),
    onDragExited: (_) => setState(() => _hover = false),
    onDragDone: (details) async {
      setState(() => _hover = false);
      if (details.files.length != 1) {
        setState(() => _error = 'Choose one photo per image type.');
        return;
      }
      await _accept(details.files.single);
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _hover ? AppColors.lightGreenCard : AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hover ? AppColors.darkGreen : AppColors.border,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 30,
            color: AppColors.darkGreen,
          ),
          const SizedBox(height: 8),
          const Text(
            'Drop a photo here',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const Text(
            'JPEG, PNG or WebP - Up to 10 MB',
            textAlign: TextAlign.center,
          ),
          TextButton.icon(
            onPressed: widget.enabled && !_reading ? _browse : null,
            icon: const Icon(Icons.folder_open),
            label: Text(_reading ? 'Checking image?' : 'Browse files'),
          ),
          if (_reading) const LinearProgressIndicator(),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
    ),
  );
}
