import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/apiary_model.dart';
import '../services/apiary_service.dart';
import '../services/relocation_monitoring_service.dart';
import '../utils/theme.dart';
import '../widgets/main_bottom_nav.dart';
import 'IT23183186_environment_dashboard_screen.dart';
import 'IT23185302_bee_detection_screen.dart';

/// Research Component IT23185302:
/// Post-Relocation Monitoring — observe bee entrance activity of a relocated
/// hive box through an ESP32-CAM, served via the FastAPI backend.
///
/// All camera frames, movement counts and activity levels come from the
/// backend; nothing is simulated on the device.
class PostRelocationMonitoringScreenIT23185302 extends StatefulWidget {
  const PostRelocationMonitoringScreenIT23185302({super.key});

  @override
  State<PostRelocationMonitoringScreenIT23185302> createState() =>
      _PostRelocationMonitoringScreenIT23185302State();
}

class _PostRelocationMonitoringScreenIT23185302State
    extends State<PostRelocationMonitoringScreenIT23185302> {
  final int _currentNavIndex = 2; // Relocate is tab index 2
  final _monitoring = RelocationMonitoringService.instance;

  static const _framePollInterval = Duration(seconds: 2);
  static const _activityPollInterval = Duration(seconds: 30);

  // Apiaries
  bool _loadingApiaries = true;
  String? _apiaryError;
  List<ApiaryModel> _apiaries = [];
  ApiaryModel? _selectedApiary;

  // Hive boxes of the selected apiary
  bool _loadingHives = false;
  String? _hiveError;
  List<HiveModel> _hives = [];
  HiveModel? _selectedHive;

  // Monitoring state for the selected hive box
  bool _loadingStatus = false;
  bool _serviceUnavailable = false;
  String? _statusError;
  MonitoringStatus? _status;

  bool _loadingActivity = false;
  String? _activityError;
  ActivitySnapshot? _activity;

  Uint8List? _frame;
  DateTime? _frameAt;
  bool _fetchingFrame = false;

  bool _actionBusy = false;

  Timer? _frameTimer;
  Timer? _activityTimer;

  @override
  void initState() {
    super.initState();
    _loadApiaries();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────

  Future<void> _loadApiaries() async {
    setState(() {
      _loadingApiaries = true;
      _apiaryError = null;
    });
    try {
      final list = await ApiaryService.instance.fetchApiaries();
      if (!mounted) return;
      final preselected = ApiaryService.instance.selectedApiary;
      ApiaryModel? initial;
      if (preselected != null) {
        for (final a in list) {
          if (a.id == preselected.id) initial = a;
        }
      }
      setState(() {
        _apiaries = list;
        _loadingApiaries = false;
      });
      if (initial != null) _onApiaryChanged(initial);
    } catch (e) {
      developer.log('Error loading apiaries: $e', name: 'PostRelocationMonitor');
      if (!mounted) return;
      setState(() {
        _loadingApiaries = false;
        _apiaryError = 'Could not load your apiaries. Pull to retry.';
      });
    }
  }

  Future<void> _onApiaryChanged(ApiaryModel? apiary) async {
    if (apiary == null || apiary.id == _selectedApiary?.id) return;
    _resetMonitoringState();
    setState(() {
      _selectedApiary = apiary;
      _selectedHive = null;
      _hives = [];
      _hiveError = null;
      _loadingHives = true;
    });
    try {
      final hives = await ApiaryService.instance.fetchHives(apiary.id);
      if (!mounted || _selectedApiary?.id != apiary.id) return;
      setState(() {
        _hives = hives;
        _loadingHives = false;
      });
    } catch (e) {
      developer.log('Error loading hives: $e', name: 'PostRelocationMonitor');
      if (!mounted || _selectedApiary?.id != apiary.id) return;
      setState(() {
        _loadingHives = false;
        _hiveError = 'Could not load hive boxes for this apiary.';
      });
    }
  }

  void _onHiveChanged(HiveModel? hive) {
    if (hive == null || hive.id == _selectedHive?.id) return;
    _resetMonitoringState();
    setState(() => _selectedHive = hive);
    _refreshAll();
  }

  void _resetMonitoringState() {
    _stopPolling();
    _status = null;
    _statusError = null;
    _serviceUnavailable = false;
    _activity = null;
    _activityError = null;
    _frame = null;
    _frameAt = null;
  }

  /// Reloads status, activity and the camera frame for the selected hive.
  Future<void> _refreshAll() async {
    final hive = _selectedHive;
    if (hive == null) return;
    setState(() {
      _loadingStatus = true;
      _statusError = null;
      _serviceUnavailable = false;
    });
    try {
      final status = await _monitoring.fetchStatus(hive.id);
      if (!mounted || _selectedHive?.id != hive.id) return;
      setState(() {
        _status = status;
        _loadingStatus = false;
        if (status.camera != CameraConnection.connected) {
          _frame = null;
          _frameAt = null;
        }
      });
    } on MonitoringUnavailableException {
      if (!mounted || _selectedHive?.id != hive.id) return;
      setState(() {
        _status = null;
        _loadingStatus = false;
        _serviceUnavailable = true;
      });
      _stopPolling();
      return;
    } catch (e) {
      developer.log('Error loading monitoring status: $e',
          name: 'PostRelocationMonitor');
      if (!mounted || _selectedHive?.id != hive.id) return;
      setState(() {
        _status = null;
        _loadingStatus = false;
        _statusError = 'Could not reach the monitoring service.';
      });
      _stopPolling();
      return;
    }
    await Future.wait([_loadActivity(), _loadFrame()]);
    _schedulePolling();
  }

  Future<void> _loadActivity() async {
    final hive = _selectedHive;
    if (hive == null) return;
    setState(() {
      _loadingActivity = true;
      _activityError = null;
    });
    try {
      final activity = await _monitoring.fetchActivity(hive.id);
      if (!mounted || _selectedHive?.id != hive.id) return;
      setState(() {
        _activity = activity;
        _loadingActivity = false;
      });
    } on MonitoringUnavailableException {
      if (!mounted || _selectedHive?.id != hive.id) return;
      setState(() {
        _activity = null;
        _loadingActivity = false;
      });
    } catch (e) {
      developer.log('Error loading activity: $e', name: 'PostRelocationMonitor');
      if (!mounted || _selectedHive?.id != hive.id) return;
      setState(() {
        _loadingActivity = false;
        _activityError = 'Could not load activity readings.';
      });
    }
  }

  Future<void> _loadFrame() async {
    final hive = _selectedHive;
    if (hive == null ||
        _fetchingFrame ||
        _status?.camera != CameraConnection.connected) {
      return;
    }
    _fetchingFrame = true;
    try {
      final bytes = await _monitoring.fetchSnapshot(hive.id);
      if (!mounted || _selectedHive?.id != hive.id) return;
      if (bytes != null) {
        setState(() {
          _frame = bytes;
          _frameAt = DateTime.now();
        });
      }
    } catch (e) {
      developer.log('Error loading camera frame: $e',
          name: 'PostRelocationMonitor');
    } finally {
      _fetchingFrame = false;
    }
  }

  void _schedulePolling() {
    _stopPolling();
    if (!mounted || _status == null) return;
    if (_status!.camera == CameraConnection.connected) {
      _frameTimer = Timer.periodic(_framePollInterval, (_) => _loadFrame());
    }
    if (_status!.monitoringActive) {
      _activityTimer =
          Timer.periodic(_activityPollInterval, (_) => _loadActivity());
    }
  }

  void _stopPolling() {
    _frameTimer?.cancel();
    _activityTimer?.cancel();
    _frameTimer = null;
    _activityTimer = null;
  }

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> _startMonitoring() => _runSessionAction(
        (id) => _monitoring.startMonitoring(id),
        'Monitoring started.',
        'Could not start monitoring',
      );

  Future<void> _stopMonitoring() => _runSessionAction(
        (id) => _monitoring.stopMonitoring(id),
        'Monitoring stopped.',
        'Could not stop monitoring',
      );

  Future<void> _runSessionAction(
    Future<MonitoringStatus> Function(String hiveId) action,
    String successMessage,
    String failurePrefix,
  ) async {
    final hive = _selectedHive;
    if (hive == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      final status = await action(hive.id);
      if (!mounted || _selectedHive?.id != hive.id) return;
      setState(() => _status = status);
      _showSnack(successMessage);
      await Future.wait([_loadActivity(), _loadFrame()]);
      _schedulePolling();
    } catch (e) {
      if (mounted) _showSnack('$failurePrefix: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _onPullToRefresh() async {
    if (_selectedHive != null) {
      await _refreshAll();
    } else {
      await _loadApiaries();
    }
  }

  void _onNavTapped(int index) {
    if (index == _currentNavIndex) {
      // Back to the Relocation dashboard.
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
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.bgSecondary,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Derived state ─────────────────────────────────────────────────

  CameraConnection get _cameraConnection {
    if (_loadingStatus && _status == null) return CameraConnection.connecting;
    return _status?.camera ?? CameraConnection.disconnected;
  }

  bool get _monitoringActive => _status?.monitoringActive ?? false;

  /// Activity level from backend analysis. "Monitoring" is only shown for an
  /// active session that has no calculated result yet.
  ActivityLevel? get _activityLevel =>
      _activity?.activityLevel ??
      (_monitoringActive ? ActivityLevel.monitoring : null);

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
          'Post-Relocation Monitoring',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.hiveLow,
          onRefresh: _onPullToRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Monitor bee entrance activity after relocation.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // ── 1. Select Hive ───────────────────────────────────
                _buildStepLabel(1, 'Select Hive'),
                const SizedBox(height: 10),
                _buildApiaryDropdown(),
                const SizedBox(height: 10),
                _buildHiveDropdown(),
                if (_selectedHive != null) ...[
                  const SizedBox(height: 10),
                  _buildSelectedHiveBadge(_selectedHive!),
                ],

                if (_serviceUnavailable) ...[
                  const SizedBox(height: 16),
                  _buildServiceUnavailableBanner(),
                ],

                // ── 2. Camera Monitoring ─────────────────────────────
                const SizedBox(height: 28),
                _buildCameraHeader(),
                const SizedBox(height: 10),
                _buildCameraPreview(),
                const SizedBox(height: 8),
                _buildUploadDetectionLink(),

                // ── 3. Bee Entrance Activity ─────────────────────────
                const SizedBox(height: 28),
                _buildStepLabel(3, 'Bee Entrance Activity'),
                const SizedBox(height: 10),
                _buildActivityCards(),

                // ── 4. Activity History ──────────────────────────────
                const SizedBox(height: 28),
                _buildStepLabel(4, 'Activity History'),
                const SizedBox(height: 10),
                _buildActivityHistory(),

                // ── 5. Post-Relocation Observation ───────────────────
                const SizedBox(height: 28),
                _buildStepLabel(5, 'Post-Relocation Observation'),
                const SizedBox(height: 10),
                _buildObservationCard(),

                // ── 6. Actions ───────────────────────────────────────
                const SizedBox(height: 28),
                _buildActionButtons(),
                const SizedBox(height: 32),
              ],
            ).animate().fadeIn(duration: 350.ms),
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onNavTapped,
      ),
    );
  }

  Widget _buildStepLabel(int step, String label) {
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
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ── 1. Select Hive ────────────────────────────────────────────────

  Widget _buildApiaryDropdown() {
    if (_loadingApiaries) {
      return const _FieldShell(child: _InlineLoader(label: 'Loading apiaries…'));
    }
    if (_apiaryError != null) {
      return _FieldShell(
        child: _InlineMessage(
          icon: Icons.cloud_off_rounded,
          color: AppColors.error,
          message: _apiaryError!,
          actionLabel: 'Retry',
          onAction: _loadApiaries,
        ),
      );
    }
    if (_apiaries.isEmpty) {
      return const _FieldShell(
        child: _InlineMessage(
          icon: Icons.location_off_outlined,
          color: AppColors.warning,
          message: 'No registered apiaries found. Add an apiary first.',
        ),
      );
    }
    return _FieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ApiaryModel>(
          isExpanded: true,
          value: _selectedApiary,
          hint: _dropdownHint('Choose an apiary'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          dropdownColor: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          items: _apiaries
              .map((a) => DropdownMenuItem<ApiaryModel>(
                    value: a,
                    child: _dropdownItem(
                      Icons.location_on_outlined,
                      a.locationName,
                      a.areaAddress,
                    ),
                  ))
              .toList(),
          onChanged: _onApiaryChanged,
        ),
      ),
    );
  }

  Widget _buildHiveDropdown() {
    if (_selectedApiary == null) {
      return const _FieldShell(
        child: _InlineMessage(
          icon: Icons.info_outline_rounded,
          color: AppColors.textSecondary,
          message: 'Select an apiary to see its hive boxes.',
        ),
      );
    }
    if (_loadingHives) {
      return const _FieldShell(child: _InlineLoader(label: 'Loading hive boxes…'));
    }
    if (_hiveError != null) {
      return _FieldShell(
        child: _InlineMessage(
          icon: Icons.cloud_off_rounded,
          color: AppColors.error,
          message: _hiveError!,
          actionLabel: 'Retry',
          onAction: () {
            final apiary = _selectedApiary!;
            _selectedApiary = null;
            _onApiaryChanged(apiary);
          },
        ),
      );
    }
    if (_hives.isEmpty) {
      return const _FieldShell(
        child: _InlineMessage(
          icon: Icons.inventory_2_outlined,
          color: AppColors.warning,
          message: 'This apiary has no hive boxes yet.',
        ),
      );
    }
    return _FieldShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HiveModel>(
          isExpanded: true,
          value: _selectedHive,
          hint: _dropdownHint('Choose a hive box'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          dropdownColor: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          items: _hives
              .map((h) => DropdownMenuItem<HiveModel>(
                    value: h,
                    child: _dropdownItem(
                      Icons.hive_outlined,
                      h.name,
                      '${h.hiveType} • ${h.numFrames} frames',
                    ),
                  ))
              .toList(),
          onChanged: _onHiveChanged,
        ),
      ),
    );
  }

  Widget _dropdownHint(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      );

  Widget _dropdownItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.hiveLow),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedHiveBadge(HiveModel hive) {
    final boxId = hive.boxNumber > 0
        ? 'Box #${hive.boxNumber.toString().padLeft(2, '0')}'
        : hive.id;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.badgeBeeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 18, color: AppColors.hiveLow),
          const SizedBox(width: 8),
          Text(
            'Hive Box ID',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$boxId • ${hive.name}',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.badgeBeeFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceUnavailableBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.badgeTempBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 20, color: AppColors.accent2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Post-relocation monitoring is not yet available on the server '
              'for this hive. Connect an ESP32-CAM to the backend to start '
              'receiving camera data.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Camera Monitoring ──────────────────────────────────────────

  Widget _buildCameraHeader() {
    return Row(
      children: [
        Expanded(child: _buildStepLabel(2, 'Camera Monitoring')),
        if (_selectedHive != null) ...[
          _CameraStatusChip(connection: _cameraConnection),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textPrimary, size: 20),
            tooltip: 'Refresh camera',
            onPressed: _loadingStatus ? null : _refreshAll,
          ),
        ],
      ],
    );
  }

  Widget _buildCameraPreview() {
    Widget content;
    if (_selectedHive == null) {
      content = const _CameraPlaceholder(
        icon: Icons.videocam_outlined,
        title: 'No hive selected',
        message: 'Select a hive box to view its entrance camera.',
      );
    } else if (_cameraConnection == CameraConnection.connecting) {
      content = const _CameraPlaceholder(
        icon: Icons.wifi_tethering_rounded,
        title: 'Connecting to camera…',
        message: 'Checking the ESP32-CAM status.',
        loading: true,
      );
    } else if (_serviceUnavailable) {
      content = const _CameraPlaceholder(
        icon: Icons.videocam_off_outlined,
        title: 'Camera not connected',
        message: 'No ESP32-CAM is linked to this hive box yet.',
      );
    } else if (_statusError != null) {
      content = _CameraPlaceholder(
        icon: Icons.cloud_off_rounded,
        title: 'Connection error',
        message: _statusError!,
        actionLabel: 'Retry',
        onAction: _refreshAll,
      );
    } else if (_cameraConnection == CameraConnection.disconnected) {
      content = _CameraPlaceholder(
        icon: Icons.videocam_off_outlined,
        title: 'Camera not connected',
        message:
            'Make sure the ESP32-CAM at the hive entrance is powered on and connected to the network.',
        actionLabel: 'Retry',
        onAction: _refreshAll,
      );
    } else if (_frame == null) {
      content = const _CameraPlaceholder(
        icon: Icons.photo_camera_outlined,
        title: 'Waiting for camera feed…',
        message: 'The camera is connected. The first frame will appear here.',
        loading: true,
      );
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_frame!, fit: BoxFit.cover, gaplessPlayback: true),
          Positioned(
            left: 10,
            top: 10,
            child: _OverlayTag(
              color: AppColors.error,
              label: _monitoringActive ? 'LIVE • MONITORING' : 'LIVE',
            ),
          ),
          if (_frameAt != null)
            Positioned(
              right: 10,
              bottom: 10,
              child: _OverlayTag(
                label: DateFormat('HH:mm:ss').format(_frameAt!),
              ),
            ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: AppColors.panelBlack,
          child: content,
        ),
      ),
    );
  }

  /// Upload-based detection with the trained model (works without a camera).
  Widget _buildUploadDetectionLink() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BeeDetectionScreenIT23185302(
              hiveId: _selectedHive?.id,
              hiveName: _selectedHive?.name,
            ),
          ),
        ),
        icon: const Icon(Icons.center_focus_strong_outlined,
            size: 18, color: AppColors.hiveLow),
        label: Text(
          'Detect bees in an uploaded photo',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.hiveLow,
          ),
        ),
      ),
    );
  }

  // ── 3. Bee Entrance Activity ──────────────────────────────────────

  Widget _buildActivityCards() {
    final movements = _activity?.latestMovementsPerMinute;
    final lastReading = _activity?.lastReadingAt;
    final level = _activityLevel;
    final loading = _loadingActivity && _activity == null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.swap_vert_rounded,
                iconBg: AppColors.badgeBeeBg,
                iconColor: AppColors.hiveLow,
                label: 'Movements / min',
                value: loading
                    ? null
                    : movements != null
                        ? movements.toStringAsFixed(movements % 1 == 0 ? 0 : 1)
                        : '—',
                caption: movements == null && !loading ? 'Not measured' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                icon: Icons.schedule_rounded,
                iconBg: AppColors.badgeWaveBg,
                iconColor: AppColors.badgeWaveFg,
                label: 'Last reading',
                value: loading
                    ? null
                    : lastReading != null
                        ? DateFormat('HH:mm').format(lastReading)
                        : '—',
                caption: lastReading != null
                    ? DateFormat('d MMM yyyy').format(lastReading)
                    : (loading ? null : 'No readings yet'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ActivityLevelCard(
          level: level,
          loading: loading,
          error: _activityError,
        ),
      ],
    );
  }

  // ── 4. Activity History ───────────────────────────────────────────

  Widget _buildActivityHistory() {
    final readings = _activity?.readings ?? const <ActivityReading>[];

    Widget body;
    if (_loadingActivity && _activity == null) {
      body = const SizedBox(
        height: 200,
        child: Center(child: _InlineLoader(label: 'Loading readings…')),
      );
    } else if (_activityError != null && readings.isEmpty) {
      body = SizedBox(
        height: 200,
        child: Center(
          child: _InlineMessage(
            icon: Icons.cloud_off_rounded,
            color: AppColors.error,
            message: _activityError!,
            actionLabel: 'Retry',
            onAction: _loadActivity,
          ),
        ),
      );
    } else if (readings.isEmpty) {
      body = const _EmptyState(
        icon: Icons.show_chart_rounded,
        title: 'No readings available',
        message:
            'Entrance activity will be charted here once the camera starts sending analysed readings.',
      );
    } else {
      body = _ActivityChart(readings: readings);
    }

    return _Card(child: body);
  }

  // ── 5. Post-Relocation Observation ────────────────────────────────

  Widget _buildObservationCard() {
    final status = _status;
    final relocatedAt = status?.relocatedAt;
    final startedAt = status?.monitoringStartedAt;
    final endAt = status?.monitoringActive == true
        ? DateTime.now()
        : status?.monitoringStoppedAt;

    String duration;
    if (startedAt == null) {
      duration = 'Not started';
    } else if (endAt == null) {
      duration = 'Since ${DateFormat('d MMM, HH:mm').format(startedAt)}';
    } else {
      duration = _formatDuration(endAt.difference(startedAt));
      if (status?.monitoringActive == true) duration += ' (ongoing)';
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(
            icon: Icons.local_shipping_outlined,
            label: 'Relocated on',
            value: relocatedAt != null
                ? DateFormat('d MMM yyyy, HH:mm').format(relocatedAt)
                : 'Not recorded',
          ),
          const Divider(height: 20, color: AppColors.border),
          _InfoRow(
            icon: Icons.timelapse_rounded,
            label: 'Monitoring duration',
            value: duration,
          ),
          const Divider(height: 20, color: AppColors.border),
          Text(
            'Observation Summary',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _observationSummary(),
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Prefers the backend's analysis summary; otherwise states plain facts
  /// derived from the recorded readings.
  String _observationSummary() {
    if (_selectedHive == null) return 'Select a hive box to view observations.';
    final activity = _activity;
    if (activity?.observationSummary != null) {
      return activity!.observationSummary!;
    }
    final readings = activity?.readings ?? const <ActivityReading>[];
    if (readings.isEmpty) {
      return 'No camera analysis is available for this hive box yet.';
    }
    final values = readings.map((r) => r.movementsPerMinute);
    final avg = values.reduce((a, b) => a + b) / readings.length;
    final peak = values.reduce(math.max);
    final fmt = DateFormat('d MMM, HH:mm');
    return '${readings.length} reading${readings.length == 1 ? '' : 's'} '
        'recorded between ${fmt.format(readings.first.timestamp)} and '
        '${fmt.format(readings.last.timestamp)}. Average '
        '${avg.toStringAsFixed(1)} and peak ${peak.toStringAsFixed(1)} '
        'movement events per minute.';
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '—';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  // ── 6. Actions ────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final hasHive = _selectedHive != null;
    final ready = hasHive &&
        !_loadingStatus &&
        !_actionBusy &&
        !_serviceUnavailable &&
        _status != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed:
                      ready && !_monitoringActive ? _startMonitoring : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textPrimary,
                    disabledBackgroundColor: AppColors.bgElevated,
                    disabledForegroundColor: AppColors.textSecondary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _actionBusy && !_monitoringActive
                      ? const _ButtonSpinner()
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    'Start Monitoring',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: ready && _monitoringActive ? _stopMonitoring : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    disabledForegroundColor: AppColors.textSecondary,
                    side: BorderSide(
                      color: ready && _monitoringActive
                          ? AppColors.error
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _actionBusy && _monitoringActive
                      ? const _ButtonSpinner(color: AppColors.error)
                      : const Icon(Icons.stop_rounded, size: 20),
                  label: Text(
                    'Stop Monitoring',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: TextButton.icon(
            onPressed: hasHive && !_loadingStatus ? _refreshAll : null,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.hiveLow,
              backgroundColor: AppColors.bgSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            icon: _loadingStatus
                ? const _ButtonSpinner(color: AppColors.hiveLow)
                : const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              'Refresh Data',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (!hasHive) ...[
          const SizedBox(height: 8),
          Text(
            'Select an apiary and a hive box to begin monitoring.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Private widgets ─────────────────────────────────────────────────

class _FieldShell extends StatelessWidget {
  final Widget child;
  const _FieldShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.hiveLow),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InlineMessage({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.bgElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CameraStatusChip extends StatelessWidget {
  final CameraConnection connection;
  const _CameraStatusChip({required this.connection});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (connection) {
      CameraConnection.connected => (
          'Connected',
          AppColors.success,
          AppColors.badgeLeafBg
        ),
      CameraConnection.connecting => (
          'Connecting',
          AppColors.warning,
          AppColors.badgeBeeBg
        ),
      CameraConnection.disconnected => (
          'Disconnected',
          AppColors.error,
          AppColors.badgeTempBg
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CameraPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColors.hiveTop),
              )
            else
              Icon(icon, size: 42, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.bgSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded,
                    size: 16, color: AppColors.hiveTop),
                label: Text(
                  actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hiveTop,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverlayTag extends StatelessWidget {
  final String label;
  final Color? color;
  const _OverlayTag({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.panelBlack.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.bgSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;

  /// Null while loading.
  final String? value;
  final String? caption;

  const _MetricCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          if (value == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.hiveLow),
              ),
            )
          else
            Text(
              value!,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          if (caption != null)
            Text(
              caption!,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _ActivityLevelCard extends StatelessWidget {
  final ActivityLevel? level;
  final bool loading;
  final String? error;

  const _ActivityLevelCard({
    required this.level,
    required this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final (label, description, icon, fg, bg) = switch (level) {
      ActivityLevel.monitoring => (
          'Monitoring',
          'Collecting entrance activity. Results will appear once enough data is analysed.',
          Icons.visibility_outlined,
          AppColors.badgeWaveFg,
          AppColors.badgeWaveBg,
        ),
      ActivityLevel.low => (
          'Low Activity',
          'Fewer entrance movements than expected for this colony.',
          Icons.trending_down_rounded,
          AppColors.warning,
          AppColors.badgeBeeBg,
        ),
      ActivityLevel.typical => (
          'Typical Activity',
          'Entrance movement is within the expected range.',
          Icons.check_circle_outline_rounded,
          AppColors.success,
          AppColors.badgeLeafBg,
        ),
      ActivityLevel.unusual => (
          'Unusual Activity',
          'Entrance movement differs noticeably from the expected pattern.',
          Icons.warning_amber_rounded,
          AppColors.error,
          AppColors.badgeTempBg,
        ),
      ActivityLevel.insufficientData => (
          'Insufficient Data',
          'Not enough readings yet to determine an activity level.',
          Icons.hourglass_empty_rounded,
          AppColors.textSecondary,
          AppColors.bgElevated,
        ),
      null => (
          'No analysis yet',
          error ?? 'Start monitoring to receive activity analysis from the camera.',
          Icons.insights_outlined,
          AppColors.textSecondary,
          AppColors.bgElevated,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.hiveLow),
                  )
                : Icon(icon, size: 22, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Activity Level',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loading ? 'Loading…' : label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: loading ? AppColors.textSecondary : fg,
                  ),
                ),
                if (!loading) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final List<ActivityReading> readings;
  const _ActivityChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final origin = readings.first.timestamp;
    double minutesOf(DateTime t) =>
        t.difference(origin).inSeconds / Duration.secondsPerMinute;

    final spots = readings
        .map((r) => FlSpot(minutesOf(r.timestamp), r.movementsPerMinute))
        .toList();
    final maxX = math.max(spots.last.x, 1.0);
    final peak = spots.map((s) => s.y).reduce(math.max);
    final maxY = peak <= 0 ? 10.0 : (peak * 1.2).ceilToDouble();
    final xInterval = maxX / 4;
    final yInterval = math.max(1.0, (maxY / 4).ceilToDouble());
    final spansDays = readings.last.timestamp.difference(origin).inHours >= 24;
    final timeFmt = DateFormat(spansDays ? 'd MMM HH:mm' : 'HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Movement events per minute',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: xInterval,
                    getTitlesWidget: (value, meta) {
                      final t = origin.add(
                          Duration(seconds: (value * 60).round()));
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          timeFmt.format(t),
                          style: GoogleFonts.inter(
                              fontSize: 9, color: AppColors.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.panelBlack,
                  getTooltipItems: (spots) => spots.map((s) {
                    final t =
                        origin.add(Duration(seconds: (s.x * 60).round()));
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} / min\n'
                      '${DateFormat('d MMM, HH:mm').format(t)}',
                      GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bgSecondary,
                      ),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: AppColors.hiveLow,
                  barWidth: 2.5,
                  dotData: FlDotData(show: spots.length <= 30),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.hiveLow.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Time',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.hiveLow),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  final Color color;
  const _ButtonSpinner({this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
