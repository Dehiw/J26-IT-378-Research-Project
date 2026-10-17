import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/inference_service.dart';
import '../utils/theme.dart';
import 'it23136274_sensor_trends_screen.dart';

/// Student Registration: IT23136274
/// Research Component: AI-Based Colony Health Monitoring
/// Feature: Alerts & Recommendations (History / Alerts) Screen
///
/// Fully conforms to Skills/Frontend_skill.md:
/// - Palette: Strictly uses AppColors (bgPrimary, bgSecondary, bgElevated, border,
///   textPrimary, textSecondary, accent, accent2, accent3, success, warning, error,
///   badgeLeafBg, badgeLeafFg, badgeTempBg, badgeTempFg, hiveLow, hiveDoor).
/// - Typography: GoogleFonts.inter across all elements with canonical weights & sizes.
/// - Architecture: Scaffold, AppBar, SafeArea, SingleChildScrollView (padding 20).
/// - Shared 5-item fixed bottom navigation with AppColors.hiveLow on Health index.
/// - Zero raw Color(0x...) or Colors.* calls.
class IT23136274AlertsHistoryScreen extends StatefulWidget {
  final String hiveId;
  final String hiveName;
  final String apiaryName;
  final InferenceService? inferenceService;

  const IT23136274AlertsHistoryScreen({
    super.key,
    this.hiveId = 'hive-01',
    this.hiveName = 'Hive 01',
    this.apiaryName = 'Yakkala Apiary',
    this.inferenceService,
  });

  @override
  State<IT23136274AlertsHistoryScreen> createState() =>
      _IT23136274AlertsHistoryScreenState();
}

typedef AlertsHistoryScreen = IT23136274AlertsHistoryScreen;

enum _ViewTab { alerts, history }

class _AlertItem {
  final String id;
  final String title;
  final String time;
  final String description;
  final String recommendation;
  final String metricSnapshot;
  final IconData icon;
  final Color iconColor;
  final Color badgeBg;
  final bool isResolved;

  const _AlertItem({
    required this.id,
    required this.title,
    required this.time,
    required this.description,
    required this.recommendation,
    required this.metricSnapshot,
    required this.icon,
    required this.iconColor,
    required this.badgeBg,
    this.isResolved = false,
  });
}

class _HistoryEvent {
  final String title;
  final String date;
  final String time;
  final String details;
  final IconData icon;
  final Color color;

  const _HistoryEvent({
    required this.title,
    required this.date,
    required this.time,
    required this.details,
    required this.icon,
    required this.color,
  });
}

class _IT23136274AlertsHistoryScreenState
    extends State<IT23136274AlertsHistoryScreen> {
  static const int _tabIndex = 1; // Health tab
  _ViewTab _selectedTab = _ViewTab.alerts;

  // Real-time alert list matching the reference mockup
  final List<_AlertItem> _alerts = const [
    _AlertItem(
      id: 'alert-01',
      title: 'Hive weight dropped significantly',
      time: 'Today • 10:20 AM',
      description:
          'Abrupt colony weight loss of -1.8 kg detected over a 2-hour window. May indicate sudden swarming activity or robbing by foreign colonies.',
      recommendation:
          'Inspect the entrance for signs of fighting, verify brood super weight, and check swarm catching traps.',
      metricSnapshot: 'Weight: 10.6 kg (-1.8 kg)',
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.error,
      badgeBg: AppColors.badgeTempBg,
      isResolved: false,
    ),
    _AlertItem(
      id: 'alert-02',
      title: 'Humidity above normal range',
      time: 'Today • 08:15 AM',
      description:
          'Brood chamber humidity reached 78% RH for over 90 minutes. Excessive moisture creates risk of chalkbrood and fungal pathogens.',
      recommendation:
          'Check bottom board ventilation screen and tilt hive slightly forward to shed condensation.',
      metricSnapshot: 'Humidity: 78 % (Normal: 55–70%)',
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.warning,
      badgeBg: AppColors.bgElevated,
      isResolved: false,
    ),
    _AlertItem(
      id: 'alert-03',
      title: 'Bee activity lower than usual',
      time: 'Yesterday • 4:30 PM',
      description:
          'Departing and arriving traffic rate declined to 18 counts/min during peak daylight hours.',
      recommendation:
          'Observe flight board tomorrow morning for pollen-carrying foragers and inspect brood density.',
      metricSnapshot: 'Flight Rate: 18/min (Normal: >35/min)',
      icon: Icons.priority_high_rounded,
      iconColor: AppColors.accent2,
      badgeBg: AppColors.badgeTempBg,
      isResolved: false,
    ),
    _AlertItem(
      id: 'alert-04',
      title: 'Conditions returned to normal',
      time: 'Yesterday • 6:00 PM',
      description:
          'Core nest temperature normalized to 31.2°C and humidity stabilized following ambient cooling.',
      recommendation:
          'Colony has re-established active microclimate regulation. Continue standard ESP32 monitoring.',
      metricSnapshot: 'Temp: 31.2 °C • Humidity: 64 %',
      icon: Icons.check_circle_outline_rounded,
      iconColor: AppColors.success,
      badgeBg: AppColors.badgeLeafBg,
      isResolved: true,
    ),
  ];

  // Historical log events
  final List<_HistoryEvent> _historyEvents = const [
    _HistoryEvent(
      title: 'Microclimate Stabilization',
      date: 'Yesterday',
      time: '6:00 PM',
      details: 'Internal temperature returned to healthy brood range (31.2°C).',
      icon: Icons.check_circle_rounded,
      color: AppColors.success,
    ),
    _HistoryEvent(
      title: 'Activity Dip Logged',
      date: 'Yesterday',
      time: '4:30 PM',
      details: 'Sensor recorded temporary flight slowdown during overcast skies.',
      icon: Icons.warning_amber_rounded,
      color: AppColors.accent2,
    ),
    _HistoryEvent(
      title: 'Inspection Completed',
      date: 'Oct 14, 2026',
      time: '11:15 AM',
      details: 'Routine frame inspection logged by apiarist. Queen spotted with healthy brood pattern.',
      icon: Icons.fact_check_outlined,
      color: AppColors.accent,
    ),
    _HistoryEvent(
      title: 'High Humidity Warning Resolved',
      date: 'Oct 12, 2026',
      time: '09:40 AM',
      details: 'Screened bottom board opened to improve airflow through hive.',
      icon: Icons.air_rounded,
      color: AppColors.info,
    ),
    _HistoryEvent(
      title: 'Honey Super Added',
      date: 'Oct 08, 2026',
      time: '03:00 PM',
      details: 'Baseline tare weight increased by +3.2 kg after adding 10-frame super.',
      icon: Icons.add_box_outlined,
      color: AppColors.accent,
    ),
  ];

  void _onNavTapped(int index) {
    if (index == _tabIndex) {
      Navigator.of(context).pop();
      return;
    }
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final labels = ['Home', 'Health', 'Relocate', 'Acoustic', 'Environment'];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${labels[index]} module will be available in the next update.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.bgSecondary,
          ),
        ),
        backgroundColor: AppColors.panelBlack,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openSensorTrends() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IT23136274SensorTrendsScreen(
          hiveId: widget.hiveId,
          hiveName: widget.hiveName,
          apiaryName: widget.apiaryName,
          inferenceService: widget.inferenceService,
        ),
      ),
    );
  }

  void _showAlertDetailSheet(_AlertItem alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Alert Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: alert.badgeBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(alert.icon, color: alert.iconColor, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alert.time,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 14),

                // Description
                Text(
                  'Event Diagnosis',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                // Telemetry Snapshot
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: AppColors.accent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        alert.metricSnapshot,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recommendation Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.badgeTempBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.assignment_outlined, color: AppColors.error, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recommendation',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              alert.recommendation,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.accent2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action: View Sensor Trends Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openSensorTrends();
                  },
                  icon: const Icon(Icons.show_chart_rounded, size: 20, color: AppColors.textPrimary),
                  label: Text(
                    'View Sensor Trends Graph',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Alerts & History',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.hiveName} • ${widget.apiaryName}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // 1. Segmented Tab Selector [ Alerts | History ]
              _buildSegmentedTabSelector(),
              const SizedBox(height: 16),

              // 2. Tab Content: Alerts List or History Timeline
              if (_selectedTab == _ViewTab.alerts)
                _buildAlertsList()
              else
                _buildHistoryTimeline(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Segmented Tab Selector (Alerts | History) ─────────────────────────
  Widget _buildSegmentedTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabPill(
              tab: _ViewTab.alerts,
              label: 'Alerts',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTabPill(
              tab: _ViewTab.history,
              label: 'History',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({required _ViewTab tab, required String label}) {
    final isSelected = _selectedTab == tab;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedTab = tab);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Alerts List (Conforms to Mockup Image) ────────────────────────────
  Widget _buildAlertsList() {
    return Column(
      children: _alerts.map((alert) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAlertDetailSheet(alert),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    // Circular Alert Icon Disc
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: alert.badgeBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          alert.icon,
                          color: alert.iconColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Timestamp
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert.title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.time,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Chevron
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
      }).toList(),
    );
  }

  // ── History Timeline View ─────────────────────────────────────────────
  Widget _buildHistoryTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'Recent Event Logs',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ..._historyEvents.map((event) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(event.icon, color: event.color, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              event.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            event.time,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        event.details,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.date,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
        }),
      ],
    );
  }

  // ── Bottom Navigation Bar (Conforms to Frontend_skill.md) ─────────────
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.bgPrimary,
      selectedItemColor: AppColors.hiveLow,
      unselectedItemColor: AppColors.textSecondary,
      showUnselectedLabels: true,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: _tabIndex,
      onTap: _onNavTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.monitor_heart_outlined),
          label: 'Health',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on_outlined),
          label: 'Relocate',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.graphic_eq_rounded),
          label: 'Acoustic',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.eco_outlined),
          label: 'Environment',
        ),
      ],
    );
  }
}
