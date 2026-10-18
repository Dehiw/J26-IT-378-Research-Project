import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme.dart';
import '../acoustic_format.dart';
import '../acoustic_strings.dart';
import '../models/abnormal_trend.dart';
import '../models/acoustic_result.dart';
import '../models/hive_names.dart';
import '../services/acoustic_service.dart';
import '../widgets/abnormality_trend_card.dart';
import '../widgets/acoustic_status_style.dart';
import '../widgets/history_filter_sheet.dart';
import 'result_screen.dart';

/// Saved analyses for one hive, newest first. Filter by status from the
/// app bar. Tap a row to open its Result in read-only mode.
class SoundHistoryScreen extends StatefulWidget {
  const SoundHistoryScreen({
    super.key,
    required this.service,
    required this.hiveId,
    this.onRecordPressed,
  });

  final AcousticService service;
  final String hiveId;

  /// Starts a recording for the hive. Null hides the Record button in the
  /// empty state.
  final Future<void> Function(String hiveId)? onRecordPressed;

  @override
  State<SoundHistoryScreen> createState() => _SoundHistoryScreenState();
}

class _SoundHistoryScreenState extends State<SoundHistoryScreen> {
  List<AcousticResult> _items = const [];

  /// Status to show; null shows every status.
  AcousticLabel? _filter;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await _rememberHiveNames();
      final saved = await widget.service.getHistory(hiveId: widget.hiveId);
      if (!mounted) return;
      final items = [
        for (final r in saved)
          if (r.hiveId == widget.hiveId) r,
      ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error, stack) {
      developer.log(
        'Failed to load sound history',
        name: 'AcousticHistory',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// Keeps hive names current for the header. Best effort: names are only
  /// for display, so a failure here does not block the list.
  Future<void> _rememberHiveNames() async {
    try {
      HiveNames.remember(await widget.service.getHives());
    } catch (error, stack) {
      developer.log(
        'Failed to load hive names',
        name: 'AcousticHistory',
        error: error,
        stackTrace: stack,
      );
    }
  }

  List<AcousticResult> get _visible => _filter == null
      ? _items
      : [
          for (final r in _items)
            if (r.displayLabel == _filter) r,
        ];

  Future<void> _pickFilter() async {
    final choice = await HistoryFilterSheet.show(context, selected: _filter);
    if (choice == null || !mounted) return;
    setState(() => _filter = choice.label);
  }

  /// Records a new sound, then reloads so a result saved there appears here.
  Future<void> _record() async {
    final onRecord = widget.onRecordPressed;
    if (onRecord == null) return;
    await onRecord(widget.hiveId);
    if (mounted) await _load();
  }

  /// Opens the Result read-only. The waveform is optional: if it cannot be
  /// loaded the Result simply has no preview.
  Future<void> _open(AcousticResult result) async {
    var waveform = const <double>[];
    try {
      waveform = await widget.service.getWaveform(result.id) ?? waveform;
    } catch (error, stack) {
      developer.log(
        'Failed to load waveform preview',
        name: 'AcousticHistory',
        error: error,
        stackTrace: stack,
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          service: widget.service,
          result: result,
          waveform: waveform,
          readOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          AcousticStrings.soundHistoryTitle,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: AcousticStrings.filterTooltip,
            onPressed: _loading || _failed || _items.isEmpty
                ? null
                : _pickFilter,
          ),
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
              AcousticStrings.historyLoading,
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
      return _CenteredMessage(
        text: AcousticStrings.historyLoadFailed,
        child: ElevatedButton(
          onPressed: _load,
          style: _buttonStyle(minimumWidth: 140),
          child: Text(AcousticStrings.tryAgain),
        ),
      );
    }

    if (_items.isEmpty) {
      return _CenteredMessage(
        text: AcousticStrings.noSavedAnalysesForHive,
        child: widget.onRecordPressed == null
            ? null
            : ElevatedButton.icon(
                onPressed: _record,
                icon: const Icon(Icons.mic_none),
                label: Text(AcousticStrings.recordHiveSound),
                style: _buttonStyle(minimumWidth: 200),
              ),
      );
    }

    final visible = _visible;
    final now = DateTime.now();
    // The trend counts the whole hive, so the status filter does not change it.
    final trend = AbnormalTrend.from(
      results: _items,
      hiveId: widget.hiveId,
      now: now,
    );
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      // Trend card and header come first, then the rows (or a no-match note).
      itemCount: 2 + (visible.isEmpty ? 1 : visible.length),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AbnormalityTrendCard(trend: trend),
          );
        }
        if (index == 1) return _buildHeader();
        if (visible.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              AcousticStrings.noMatchingAnalyses,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        final result = visible[index - 2];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _HistoryRow(
            result: result,
            now: now,
            onTap: () => _open(result),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final filter = _filter;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AcousticStrings.recentRecordings,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            HiveNames.of(widget.hiveId),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (filter != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    AcousticStrings.showingFilter(
                      AcousticStrings.labelTitle(filter),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _filter = null),
                  child: Text(AcousticStrings.showAll),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static ButtonStyle _buttonStyle({required double minimumWidth}) {
    return ElevatedButton.styleFrom(
      minimumSize: Size(minimumWidth, 48),
      elevation: 0,
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.textPrimary,
      shape: const StadiumBorder(),
    );
  }
}

/// Loading, empty and error states share this layout: text, then an
/// optional action.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text, this.child});

  final String text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            if (child != null) ...[const SizedBox(height: 20), child!],
          ],
        ),
      ),
    );
  }
}

/// One saved analysis: status chip (icon and name), then day, time and
/// confidence. The whole row is the tap target.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.result,
    required this.now,
    required this.onTap,
  });

  final AcousticResult result;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = result.displayLabel;
    final title = AcousticStrings.labelTitle(label);
    final when = AcousticFormat.dayAndTime(result.recordedAt, now);
    final percent = AcousticStrings.percent(result.confidence);

    return Semantics(
      button: true,
      label: '$title, $when, $percent confidence',
      excludeSemantics: true,
      child: Material(
        color: AppColors.bgCard,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusChip(label: label, title: title),
                      const SizedBox(height: 8),
                      Text(
                        '$when · $percent conf',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.title});

  final AcousticLabel label;
  final String title;

  @override
  Widget build(BuildContext context) {
    final style = AcousticStatusStyle.of(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.chipBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 16, color: style.iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
