import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme.dart';
import '../acoustic_strings.dart';
import '../models/acoustic_result.dart';
import '../models/hive_names.dart';
import '../models/hive_option.dart';
import '../services/acoustic_service.dart';
import '../services/audio_upload.dart';
import '../services/mock_acoustic_service.dart';
import '../widgets/demo_notice.dart';
import '../widgets/hive_picker_sheet.dart';
import '../widgets/hive_selector_card.dart';
import '../widgets/latest_status_card.dart';
import '../widgets/recent_analysis_tile.dart';
import 'sound_history_screen.dart';

/// Hive Sound Monitor: pick a hive, see its latest sound state, and start
/// a recording or an upload.
///
/// Record is enabled when [onRecordPressed] is supplied. Upload is enabled
/// when both [filePicker] and [onAudioPicked] are supplied. The Monitor
/// validates the picked file itself and shows problems in a message bar.
/// After either callback finishes, the Monitor reloads its history.
class HiveSoundMonitorScreen extends StatefulWidget {
  const HiveSoundMonitorScreen({
    super.key,
    this.service,
    this.onRecordPressed,
    this.filePicker,
    this.onAudioPicked,
    this.onHistoryPressed,
    this.extraAppBarActions = const [],
    this.initialHiveId,
  });

  /// Hive to select when the Monitor opens. Ignored if it is not in the
  /// hive list; the first hive is used then.
  final String? initialHiveId;

  /// Defaults to [MockAcousticService] when not supplied.
  final AcousticService? service;

  /// Starts a recording for the given hive.
  final Future<void> Function(String hiveId)? onRecordPressed;

  /// Opens the system file picker. Null disables Upload.
  final AudioFilePicker? filePicker;

  /// Analyses a validated upload for the given hive.
  final Future<void> Function(String hiveId, PickedAudio audio)? onAudioPicked;

  final VoidCallback? onHistoryPressed;

  /// Extra icons shown after the history icon. Used by the dev entry only.
  final List<Widget> extraAppBarActions;

  @override
  State<HiveSoundMonitorScreen> createState() => _HiveSoundMonitorScreenState();
}

class _HiveSoundMonitorScreenState extends State<HiveSoundMonitorScreen> {
  static const int _recentLimit = 5;

  late final AcousticService _service = widget.service ?? MockAcousticService();

  List<HiveOption> _hives = const [];
  List<AcousticResult> _history = const [];
  String? _selectedHiveId;
  List<double>? _waveform;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _selectedHiveId = widget.initialHiveId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final hives = await _service.getHives();
      HiveNames.remember(hives);
      final history = await _service.getHistory();
      if (!mounted) return;
      setState(() {
        _hives = hives;
        _history = history;
        _loading = false;
        final stillValid = hives.any((h) => h.id == _selectedHiveId);
        if (!stillValid) {
          _selectedHiveId = hives.isEmpty ? null : hives.first.id;
        }
      });
      await _loadWaveform();
    } catch (error, stack) {
      developer.log(
        'Failed to load hive sounds',
        name: 'AcousticMonitor',
        error: error,
        stackTrace: stack,
      );
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// The waveform preview is optional: any failure just hides it.
  Future<void> _loadWaveform() async {
    final latest = _latestForSelectedHive;
    if (latest == null) {
      if (mounted) setState(() => _waveform = null);
      return;
    }
    try {
      final samples = await _service.getWaveform(latest.id);
      if (mounted && latest.id == _latestForSelectedHive?.id) {
        setState(() => _waveform = samples);
      }
    } catch (error, stack) {
      developer.log(
        'Failed to load waveform preview',
        name: 'AcousticMonitor',
        error: error,
        stackTrace: stack,
      );
      if (mounted) setState(() => _waveform = null);
    }
  }

  Future<void> _pickHive() async {
    final id = await HivePickerSheet.show(
      context,
      hives: _hives,
      selectedId: _selectedHiveId,
    );
    if (id == null || id == _selectedHiveId) return;
    setState(() => _selectedHiveId = id);
    await _loadWaveform();
  }

  List<AcousticResult> get _hiveHistory =>
      _history.where((r) => r.hiveId == _selectedHiveId).toList();

  AcousticResult? get _latestForSelectedHive {
    final forHive = _hiveHistory;
    return forHive.isEmpty ? null : forHive.first;
  }

  HiveOption? get _selectedHive {
    for (final hive in _hives) {
      if (hive.id == _selectedHiveId) return hive;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          AcousticStrings.appBarMonitorTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: AcousticStrings.soundHistoryTooltip,
            onPressed: widget.onHistoryPressed ?? () => _openHistory(),
          ),
          ...widget.extraAppBarActions,
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              AcousticStrings.loadingHiveSounds,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AcousticStrings.loadFailed,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(44, 48),
                  elevation: 0,
                ),
                child: Text(AcousticStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final hive = _selectedHive;
    final recent = _hiveHistory.take(_recentLimit).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          HiveSelectorCard(
            hive: hive,
            onTap: _hives.isEmpty ? null : _pickHive,
          ),
          const SizedBox(height: 16),
          if (_service.isDemo) ...[
            const DemoNotice(compact: true),
            const SizedBox(height: 16),
          ],
          LatestStatusCard(
            result: _latestForSelectedHive,
            waveform: _waveform,
            now: now,
          ),
          const SizedBox(height: 16),
          _buildRecordButton(),
          const SizedBox(height: 12),
          _buildUploadButton(),
          const SizedBox(height: 24),
          Text(
            AcousticStrings.recentAnalyses,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Text(
              hive == null
                  ? AcousticStrings.noHivesFound
                  : AcousticStrings.noAnalysesForHive,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            )
          else
            for (final result in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RecentAnalysisTile(result: result, now: now),
              ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Opens Sound History for the selected hive. Reloads on return, in case a
  /// recording was saved from there.
  Future<void> _openHistory() async {
    final hiveId = _selectedHiveId;
    if (hiveId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SoundHistoryScreen(
          service: _service,
          hiveId: hiveId,
          onRecordPressed: widget.onRecordPressed,
        ),
      ),
    );
    if (mounted) await _load();
  }

  /// Runs a flow for the selected hive, then reloads history so a saved
  /// result appears in Recent analyses.
  Future<void> _runFlow(Future<void> Function() flow) async {
    await flow();
    if (mounted) await _load();
  }

  Future<void> _uploadAudio() async {
    final hiveId = _selectedHiveId;
    final picker = widget.filePicker;
    final onPicked = widget.onAudioPicked;
    if (hiveId == null || picker == null || onPicked == null) return;

    PickedAudio? audio;
    try {
      audio = await picker.pick();
    } catch (error, stack) {
      developer.log(
        'File picker failed',
        name: 'AcousticMonitor',
        error: error,
        stackTrace: stack,
      );
      _showMessage(AcousticStrings.uploadPickFailed);
      return;
    }
    if (audio == null || !mounted) return;

    final problem = AudioUploadValidator.check(audio);
    if (problem != null) {
      _showMessage(AudioUploadValidator.message(problem));
      return;
    }
    await _runFlow(() => onPicked(hiveId, audio!));
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.bgPrimary),
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRecordButton() {
    final hiveId = _selectedHiveId;
    final onRecord = widget.onRecordPressed;
    return ElevatedButton.icon(
      onPressed: (onRecord == null || hiveId == null)
          ? null
          : () => _runFlow(() => onRecord(hiveId)),
      icon: const Icon(Icons.mic_outlined),
      label: Text(
        AcousticStrings.recordHiveSound,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        elevation: 0,
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.textPrimary,
        disabledBackgroundColor: AppColors.bgElevated,
        disabledForegroundColor: AppColors.textMuted,
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _buildUploadButton() {
    final enabled =
        _selectedHiveId != null &&
        widget.filePicker != null &&
        widget.onAudioPicked != null;
    return OutlinedButton.icon(
      onPressed: enabled ? _uploadAudio : null,
      icon: const Icon(Icons.file_upload_outlined),
      label: Text(
        AcousticStrings.uploadAudio,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        foregroundColor: AppColors.textPrimary,
        disabledForegroundColor: AppColors.textMuted,
        side: BorderSide(color: enabled ? AppColors.accent : AppColors.border),
        shape: const StadiumBorder(),
      ),
    );
  }
}
