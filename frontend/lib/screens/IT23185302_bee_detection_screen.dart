import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../services/relocation_monitoring_service.dart';
import '../utils/theme.dart';
import '../widgets/confidence_bar.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/main_bottom_nav.dart';
import 'IT23183186_environment_dashboard_screen.dart';

/// Research Component IT23185302:
/// Bee Detection & Monitoring — runs the trained YOLOv8n bee detector on the
/// FastAPI backend for an image chosen by the beekeeper.
///
/// Every count, box and confidence shown here comes from the backend model.
/// ESP32-CAM capture is not connected yet; it will post frames to the same
/// detection endpoint.
class BeeDetectionScreenIT23185302 extends StatefulWidget {
  /// Optional hive box the image belongs to (sent to the backend as context).
  final String? hiveId;
  final String? hiveName;

  const BeeDetectionScreenIT23185302({super.key, this.hiveId, this.hiveName});

  @override
  State<BeeDetectionScreenIT23185302> createState() =>
      _BeeDetectionScreenIT23185302State();
}

class _BeeDetectionScreenIT23185302State
    extends State<BeeDetectionScreenIT23185302> {
  final int _currentNavIndex = 2; // Relocate is tab index 2
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  String _imageName = 'bees.jpg';

  bool _running = false;
  String? _error;
  BeeDetectionResult? _result;
  int? _selectedBox;
  bool _showBoxes = true;

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = file.name.isEmpty ? 'bees.jpg' : file.name;
        _result = null;
        _error = null;
        _selectedBox = null;
      });
    } catch (e) {
      developer.log('Image pick failed: $e', name: 'BeeDetectionIT23185302');
      _showSnack('Could not open the image: $e', isError: true);
    }
  }

  void _chooseImage() {
    ImageSourceSheet.show(
      context,
      onCamera: () => _pickImage(ImageSource.camera),
      onGallery: () => _pickImage(ImageSource.gallery),
    );
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _result = null;
      _error = null;
      _selectedBox = null;
    });
  }

  Future<void> _runDetection() async {
    final bytes = _imageBytes;
    if (bytes == null || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _result = null;
      _selectedBox = null;
    });
    try {
      final result = await RelocationMonitoringService.instance.detectBees(
        bytes,
        filename: _imageName,
        hiveId: widget.hiveId,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _onNavTapped(int index) {
    if (index == _currentNavIndex) {
      Navigator.of(context).pop();
      return;
    }
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const EnvironmentDashboardScreen(),
        ),
      );
      return;
    }
    _showSnack('Module tab $index will be available in the upcoming update.');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppColors.error : AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: AppColors.bgSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary, size: 24),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Bee Detection & Monitoring',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                widget.hiveName != null
                    ? 'Detect bees at the entrance of ${widget.hiveName}.'
                    : 'Detect bees in a hive entrance or landing-board photo.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              const _CameraNotice(),
              const SizedBox(height: 24),

              // ── 1. Image ──────────────────────────────────────────
              const _StepLabel(step: 1, label: 'Select Image'),
              const SizedBox(height: 10),
              _buildImageCard(),
              const SizedBox(height: 16),
              _buildRunButton(),

              // ── 2. Results ────────────────────────────────────────
              if (_running || _error != null || _result != null) ...[
                const SizedBox(height: 28),
                const _StepLabel(step: 2, label: 'Detection Results'),
                const SizedBox(height: 10),
                _buildResults(),
              ],
              const SizedBox(height: 32),
            ],
          ).animate().fadeIn(duration: 350.ms),
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onNavTapped,
      ),
    );
  }

  // ── 1. Image selection ────────────────────────────────────────────

  Widget _buildImageCard() {
    final bytes = _imageBytes;
    if (bytes == null) {
      return GestureDetector(
        onTap: _chooseImage,
        child: _Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.bgSecondary, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload a bee image',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Take a photo or choose one from the gallery.\nJPEG, PNG or WebP, up to 10 MB.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Container(
              color: AppColors.panelBlack,
              constraints: const BoxConstraints(maxHeight: 260),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              children: [
                const Icon(Icons.image_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _imageName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _running ? null : _chooseImage,
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hiveLow,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove image',
                  onPressed: _running ? null : _clearImage,
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunButton() {
    final enabled = _imageBytes != null && !_running;
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: enabled ? _runDetection : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.bgElevated,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textPrimary),
              )
            : const Icon(Icons.search_rounded, size: 20),
        label: Text(
          _running ? 'Running Detection…' : 'Run Detection',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: enabled || _running
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── 2. Results ────────────────────────────────────────────────────

  Widget _buildResults() {
    if (_running) {
      return const _Card(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: _InlineLoader(label: 'Analysing image with the bee model…'),
          ),
        ),
      );
    }
    if (_error != null) {
      return _StatusBanner(
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
        title: 'Detection failed',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _runDetection,
      );
    }

    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        result.hasBees
            ? _StatusBanner(
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                title: 'Detection successful',
                message:
                    '${result.beeCount} ${result.beeCount == 1 ? 'bee' : 'bees'} detected above the '
                    '${(result.confidenceThreshold * 100).round()}% confidence threshold.',
              )
            : _StatusBanner(
                icon: Icons.search_off_rounded,
                color: AppColors.warning,
                title: 'No bees detected',
                message:
                    'The model found no bees above the '
                    '${(result.confidenceThreshold * 100).round()}% confidence threshold. '
                    'Try a sharper, closer photo of the hive entrance or landing board.',
              ),
        const SizedBox(height: 12),
        _buildAnnotatedImage(result),
        const SizedBox(height: 12),
        _buildStats(result),
        if (result.hasBees) ...[
          const SizedBox(height: 12),
          _buildDetectionList(result),
        ],
        const SizedBox(height: 12),
        _buildModelInfo(result),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildAnnotatedImage(BeeDetectionResult result) {
    final bytes = result.processedImage ?? _imageBytes;
    if (bytes == null || result.imageWidth <= 0 || result.imageHeight <= 0) {
      return const SizedBox.shrink();
    }
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: AspectRatio(
              aspectRatio: result.imageWidth / result.imageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes, fit: BoxFit.fill),
                  if (_showBoxes)
                    CustomPaint(
                      painter: _BeeBoxPainter(
                        detections: result.detections,
                        selected: _selectedBox,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    result.hasBees
                        ? 'Tap a detection below to highlight it.'
                        : 'Analysed image',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (result.hasBees) ...[
                  Text(
                    'Boxes',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Switch(
                    value: _showBoxes,
                    activeThumbColor: AppColors.hiveLow,
                    onChanged: (v) => setState(() => _showBoxes = v),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BeeDetectionResult result) {
    String pct(double? v) => v == null ? '–' : '${(v * 100).round()}%';
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.emoji_nature_outlined,
            label: 'Bees detected',
            value: '${result.beeCount}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.trending_up_rounded,
            label: 'Highest confidence',
            value: pct(result.maxConfidence),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.analytics_outlined,
            label: 'Average confidence',
            value: pct(result.meanConfidence),
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionList(BeeDetectionResult result) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Detections (${result.detections.length})',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < result.detections.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _showBoxes = true;
                _selectedBox = _selectedBox == i ? null : i;
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedBox == i
                      ? AppColors.badgeBeeBg
                      : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ConfidenceBar(
                  label: 'Bee #${i + 1}',
                  confidence: result.detections[i].confidence,
                  isTopPrediction: true,
                  animationDelayMs: (i * 40).clamp(0, 400),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModelInfo(BeeDetectionResult result) {
    final time = result.analyzedAt != null
        ? DateFormat('d MMM yyyy, h:mm a').format(result.analyzedAt!)
        : null;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result.modelName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Threshold ${(result.confidenceThreshold * 100).round()}%',
              if (result.inferenceMs != null)
                'Inference ${result.inferenceMs!.round()} ms',
              ?time,
            ].join('  ·  '),
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textSecondary),
          ),
          if (result.limitations.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Text(
              'Limitations',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            for (final note in result.limitations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $note',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Box overlay ───────────────────────────────────────────────────────

class _BeeBoxPainter extends CustomPainter {
  final List<BeeDetection> detections;
  final int? selected;

  _BeeBoxPainter({required this.detections, required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = (size.shortestSide / 160).clamp(1.5, 3.0);
    for (var i = 0; i < detections.length; i++) {
      final b = detections[i].bboxNormalized;
      final rect = Rect.fromLTRB(
        b[0] * size.width,
        b[1] * size.height,
        b[2] * size.width,
        b[3] * size.height,
      );
      final isSelected = selected == i;
      final dimmed = selected != null && !isSelected;
      final color = isSelected
          ? AppColors.error
          : AppColors.hiveTop.withValues(alpha: dimmed ? 0.45 : 1);

      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? stroke + 1 : stroke
          ..color = color,
      );

      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}  ${(detections[i].confidence * 100).round()}%',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.bgSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final tagHeight = label.height + 2;
      final top = rect.top - tagHeight >= 0 ? rect.top - tagHeight : rect.top;
      final tag = Rect.fromLTWH(rect.left, top, label.width + 6, tagHeight);
      canvas.drawRect(
        tag,
        Paint()
          ..color = isSelected
              ? AppColors.error
              : AppColors.panelBlack.withValues(alpha: dimmed ? 0.4 : 0.8),
      );
      label.paint(canvas, Offset(tag.left + 3, tag.top + 1));
    }
  }

  @override
  bool shouldRepaint(_BeeBoxPainter old) =>
      old.detections != detections || old.selected != selected;
}

// ── Small UI pieces ───────────────────────────────────────────────────

class _CameraNotice extends StatelessWidget {
  const _CameraNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.badgeWaveBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.videocam_off_outlined,
              size: 18, color: AppColors.badgeWaveFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ESP32-CAM capture is not connected yet. Upload a photo to run '
              'the same trained model the camera will use.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int step;
  final String label;
  const _StepLabel({required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: AppColors.accentGradient,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$step',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.bgSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InlineLoader extends StatelessWidget {
  final String label;
  const _InlineLoader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: AppColors.hiveLow),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.hiveLow,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.hiveLow),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
