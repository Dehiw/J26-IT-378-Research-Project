import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/api_config.dart';
import '../utils/theme.dart';

/// Real, on-demand OpenStreetMap tiles. No illustrative geography or radar.
class ApiaryWeatherMap extends StatefulWidget {
  final double latitude, longitude;
  final String locationName;
  final String? weatherLabel;
  const ApiaryWeatherMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    this.weatherLabel,
  });
  @override
  State<ApiaryWeatherMap> createState() => _ApiaryMapState();
}

class _ApiaryMapState extends State<ApiaryWeatherMap> {
  int _zoom = 8;
  late double _latitude, _longitude;
  bool _showWeather = true;
  int _retry = 0;
  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant ApiaryWeatherMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _reset();
    }
  }

  void _reset() {
    _latitude = widget.latitude;
    _longitude = widget.longitude;
  }

  Offset _pixel(double lat, double lon) {
    final size = 256.0 * math.pow(2, _zoom);
    final sine = math.sin(lat.clamp(-85.0511, 85.0511) * math.pi / 180);
    return Offset(
      (lon + 180) / 360 * size,
      (0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi)) * size,
    );
  }

  void _pan(DragUpdateDetails details) {
    final p = _pixel(_latitude, _longitude) - details.delta;
    final size = 256.0 * math.pow(2, _zoom);
    final y = p.dy.clamp(0, size);
    final n = math.pi - 2 * math.pi * y / size;
    setState(() {
      _longitude = ((p.dx / size * 360) % 360) - 180;
      _latitude = (180 / math.pi * math.atan((math.exp(n) - math.exp(-n)) / 2))
          .clamp(-85.0511, 85.0511);
    });
  }

  Widget _control(IconData icon, String tooltip, VoidCallback? onPressed) =>
      Material(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: AppColors.textPrimary),
        ),
      );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      height: 380,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = _pixel(_latitude, _longitude);
          final width = constraints.maxWidth;
          final left = center.dx - width / 2, top = center.dy - 190;
          final tiles = <Widget>[];
          final count = 1 << _zoom;
          for (
            var tx = (left / 256).floor();
            tx <= ((left + width) / 256).floor();
            tx++
          ) {
            for (
              var ty = (top / 256).floor();
              ty <= ((top + 380) / 256).floor();
              ty++
            ) {
              if (ty < 0 || ty >= count) continue;
              final url =
                  '${ApiConfig.baseUrl}/environment/map/tiles/$_zoom/${tx % count}/$ty.png';
              tiles.add(
                Positioned(
                  left: tx * 256 - left,
                  top: ty * 256 - top,
                  width: 256,
                  height: 256,
                  child: Image.network(
                    url,
                    key: ValueKey('$url-$_retry'),
                    fit: BoxFit.fill,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.badgeWaveBg,
                      child: const Center(
                        child: Icon(
                          Icons.cloud_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(color: AppColors.badgeWaveBg),
                  ),
                ),
              );
            }
          }
          final marker = _pixel(widget.latitude, widget.longitude);
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              GestureDetector(
                onPanUpdate: _pan,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: Container(color: AppColors.badgeWaveBg),
                    ),
                    ...tiles,
                    Positioned(
                      left: marker.dx - left - 20,
                      top: marker.dy - top - 38,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.accent2,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Material(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          color: AppColors.accent3,
                        ),
                        const SizedBox(width: 6),
                        const Text('Map'),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Toggle apiary weather label',
                          onPressed: () =>
                              setState(() => _showWeather = !_showWeather),
                          icon: Icon(
                            Icons.cloud_outlined,
                            color: _showWeather
                                ? AppColors.hiveLow
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Column(
                  children: [
                    _control(
                      Icons.add,
                      'Zoom in',
                      _zoom < 18 ? () => setState(() => _zoom++) : null,
                    ),
                    const SizedBox(height: 6),
                    _control(
                      Icons.remove,
                      'Zoom out',
                      _zoom > 2 ? () => setState(() => _zoom--) : null,
                    ),
                    const SizedBox(height: 6),
                    _control(
                      Icons.my_location,
                      'Center on apiary',
                      () => setState(_reset),
                    ),
                    const SizedBox(height: 6),
                    _control(
                      Icons.refresh,
                      'Retry map tiles',
                      () => setState(() => _retry++),
                    ),
                  ],
                ),
              ),
              if (_showWeather)
                Positioned(
                  left: 12,
                  right: 70,
                  bottom: 38,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.weatherLabel ?? 'Saved apiary location',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppColors.bgCard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    '© OpenStreetMap contributors | Drag to pan',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
