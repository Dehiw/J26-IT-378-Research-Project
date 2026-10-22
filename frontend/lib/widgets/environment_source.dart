import 'dart:async';

import 'package:flutter/material.dart';

import '../services/environment_fallback.dart';
import '../utils/theme.dart';

class SourceDot extends StatelessWidget {
  final String source;
  final bool compact;
  const SourceDot({super.key, required this.source, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final demo = source == 'demo';
    final cached = source == 'cached';
    final text = demo
        ? 'Demo data'
        : cached
        ? 'Saved actual data'
        : source == 'unavailable'
        ? 'Unavailable'
        : 'Actual data';
    return Tooltip(
      message: demo
          ? 'Prepared demonstration, not live readings or an analysis of your upload.'
          : cached
          ? 'Previously retrieved actual data. Not a live observation.'
          : text,
      child: Semantics(
        label: text,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: demo
                    ? AppColors.panelBlack
                    : source == 'unavailable'
                    ? AppColors.textSecondary
                    : AppColors.error,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(fontSize: 11, color: AppColors.info),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Retry visible fallback pages, without a global switch replacing live sections.
class EnvironmentRecovery extends StatefulWidget {
  final Widget child;
  final bool Function()? needed;
  final Future<void> Function() onRetry;
  const EnvironmentRecovery({
    super.key,
    required this.child,
    required this.onRetry,
    this.needed,
  });
  @override
  State<EnvironmentRecovery> createState() => _EnvironmentRecoveryState();
}

class _EnvironmentRecoveryState extends State<EnvironmentRecovery> {
  Timer? _timer;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    EnvironmentFallback.instance.addListener(_schedule);
    _schedule();
  }

  void _schedule() {
    if (!EnvironmentFallback.instance.needsRecovery ||
        widget.needed?.call() == false) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) async {
      if (widget.needed?.call() == false) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      if (!mounted ||
          _busy ||
          ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
        return;
      }
      _busy = true;
      try {
        await widget.onRetry();
      } catch (_) {
        /* Services retain their labelled fallback. */
      } finally {
        _busy = false;
      }
    });
  }

  @override
  void didUpdateWidget(covariant EnvironmentRecovery oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    EnvironmentFallback.instance.removeListener(_schedule);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String displayIdentifier(dynamic value) =>
    (value?.toString() ?? 'Not available')
        .replaceAll(RegExp(r'IT\d{8}[_-]?', caseSensitive: false), '')
        .replaceAll('_', ' ');
