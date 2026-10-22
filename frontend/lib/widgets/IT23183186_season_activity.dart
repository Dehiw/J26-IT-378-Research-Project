import 'package:flutter/material.dart';

import '../services/weather_service.dart';
import 'environment_source.dart';

const seasonGreen = Color(0xFF123C2D);
const seasonGold = Color(0xFFFFD15A);

class SeasonImage extends StatelessWidget {
  final String name;
  final double height;
  const SeasonImage(this.name, {super.key, this.height = 150});
  @override
  Widget build(BuildContext context) => Image.asset(
    'lib/utils/images/$name.png',
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    excludeFromSemantics: true,
    errorBuilder: (_, error, stack) => Container(
      height: height,
      color: const Color(0xFFE6EEDD),
      child: const Icon(
        Icons.local_florist_outlined,
        size: 44,
        color: seasonGreen,
      ),
    ),
  );
}

class SeasonActivityPanel extends StatelessWidget {
  final EnvironmentalImpact impact;
  final CurrentWeather? weather;
  final VoidCallback? onViewMore;
  const SeasonActivityPanel({
    super.key,
    required this.impact,
    this.weather,
    this.onViewMore,
  });

  Widget _metric(IconData icon, String title, String value) => Container(
    width: 155,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4EA),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: seasonGreen),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: seasonGreen,
          ),
        ),
      ],
    ),
  );

  Widget _card(
    String title,
    String image,
    IconData icon,
    Map<String, dynamic> data,
  ) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDDE5D8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeasonImage(image, height: 130),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: seasonGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: seasonGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2CE),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  data['assessment']?.toString() ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data['reason']?.toString() ??
                    'Local hive observations are needed.',
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SourceDot(source: impact.source),
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            const SeasonImage('01_bee_on_flower_hero', height: 290),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      seasonGreen,
                      seasonGreen.withValues(alpha: .55),
                      Colors.transparent,
                    ],
                    stops: const [0, .7, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SEASON & COLONY ACTIVITY',
                    style: TextStyle(
                      color: seasonGold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    impact.season,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    impact.seasonPeriod,
                    style: const TextStyle(
                      color: seasonGold,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    weather?.locationName ?? 'Selected apiary',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sri Lankan calendar season • General regional context',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text(
        impact.regionalContext,
        style: const TextStyle(fontSize: 12, height: 1.5, color: seasonGreen),
      ),
      const SizedBox(height: 18),
      const Text(
        'Outdoor conditions',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: seasonGreen,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        impact.environmentalSummary,
        style: const TextStyle(fontSize: 12, height: 1.6),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in [
              _metric(
                Icons.thermostat_outlined,
                'Temperature',
                weather == null
                    ? 'Unavailable'
                    : '${weather!.temperatureC.toStringAsFixed(1)} °C',
              ),
              _metric(
                Icons.water_drop_outlined,
                'Humidity',
                weather == null
                    ? 'Unavailable'
                    : '${weather!.humidityPercent}%',
              ),
              _metric(
                Icons.grain,
                'Rainfall observation',
                weather == null
                    ? 'Unavailable'
                    : '${weather!.precipitationMm} mm',
              ),
              _metric(
                Icons.air,
                'Wind speed',
                weather == null ? 'Unavailable' : '${weather!.windKph} km/h',
              ),
            ])
              SizedBox(
                width: box.maxWidth >= 700
                    ? (box.maxWidth - 30) / 4
                    : (box.maxWidth - 10) / 2,
                child: metric,
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 950
              ? 3
              : box.maxWidth >= 600
              ? 2
              : 1;
          final cards = [
            _card(
              'Bee activity',
              '02_bee_activity_honeycomb',
              Icons.hive_outlined,
              impact.beeActivity,
            ),
            _card(
              'Colony growth',
              '03_flowering_plant',
              Icons.trending_up,
              impact.colonyGrowth,
            ),
            _card(
              'Food availability',
              '05_bees_on_honeycomb',
              Icons.eco_outlined,
              impact.foodAvailability,
            ),
            _card(
              'Population',
              '06_hive_box',
              Icons.groups_outlined,
              impact.population,
            ),
            _card(
              'Development conditions',
              '04_beehive_in_garden',
              Icons.calendar_month_outlined,
              impact.developmentSuitability,
            ),
          ];
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final card in cards)
                SizedBox(
                  width: (box.maxWidth - 14 * (columns - 1)) / columns,
                  child: card,
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3EC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended actions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: seasonGreen,
              ),
            ),
            for (final action in impact.recommendations)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: seasonGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'WeatherAPI outdoor observation • ${weather?.updatedAt ?? 'Time unavailable'}',
        style: const TextStyle(fontSize: 11),
      ),
      const SizedBox(height: 6),
      const Text(
        'Calendar guidance is not a live seasonal forecast. Weather alone cannot establish colony health, population or food stores.',
        style: TextStyle(fontSize: 11, height: 1.5),
      ),
      if (onViewMore != null) ...[
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: seasonGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(18),
          ),
          onPressed: onViewMore,
          icon: const Icon(Icons.eco_outlined),
          label: const Text(
            'View more about seasonal changes',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ],
  );
}
