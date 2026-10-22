import 'package:flutter/material.dart';

import '../services/weather_service.dart';
import '../utils/theme.dart';
import '../widgets/environment_source.dart';
import '../widgets/IT23183186_season_activity.dart';

/// Source-backed reference guidance, separate from measured apiary conditions.
class IT23183186SeasonalChangesScreen extends StatefulWidget {
  final EnvironmentalImpact impact;
  final CurrentWeather? weather;
  final String location;
  const IT23183186SeasonalChangesScreen({
    super.key,
    required this.impact,
    this.weather,
    required this.location,
  });

  @override
  State<IT23183186SeasonalChangesScreen> createState() =>
      _SeasonalChangesState();
}

class _SeasonalChangesState extends State<IT23183186SeasonalChangesScreen> {
  WeatherImpactResponse? _current;
  EnvironmentalImpact get impact => _current?.analysis ?? widget.impact;
  CurrentWeather? get weather => _current?.weather ?? widget.weather;
  String get location => widget.location;
  Future<void> _recover() async {
    if (impact.source == 'live') return;
    final value = await const WeatherService().fetchImpact(location);
    if (mounted) setState(() => _current = value);
  }

  Widget _section(String title, String body, {String? image}) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDFE7DB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (image != null) SeasonImage(image, height: 190),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: seasonGreen,
                ),
              ),
              const SizedBox(height: 10),
              Text(body, style: const TextStyle(fontSize: 13, height: 1.7)),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => EnvironmentRecovery(
    needed: () => impact.source != 'live',
    onRetry: _recover,
    child: _buildPage(context),
  );
  Widget _buildPage(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgPrimary,
    appBar: AppBar(title: const Text('Seasonal changes')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SourceDot(source: impact.source),
                _section(
                  'Sri Lanka • A year in the bee yard',
                  '$location\n${impact.season} | ${impact.seasonPeriod}\n${impact.regionalContext}',
                  image: '01_bee_on_flower_hero',
                ),
                const Text(
                  'The four rainfall seasons',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: seasonGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Calendar reference for Sri Lanka. Local rainfall varies with region and terrain.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 16),
                for (final season in const [
                  (
                    'Northeast Monsoon',
                    'December–February',
                    'Rainfall influence is especially relevant to the north and east. Compare the calendar period with local observations.',
                  ),
                  (
                    'First Inter-monsoon',
                    'March–April',
                    'A transition between monsoons. Use local weather and flowering records to plan hive visits.',
                  ),
                  (
                    'Southwest Monsoon',
                    'May–September',
                    'Rainfall influence is especially relevant to the southwest. Actual conditions differ across the island.',
                  ),
                  (
                    'Second Inter-monsoon',
                    'October–November',
                    'A transition period with rain across the island. A seasonal label does not indicate that rain is occurring at your hive.',
                  ),
                ])
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: impact.season == season.$1
                          ? seasonGreen
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCE5D7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (impact.season == season.$1)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'SELECTED OBSERVATION SEASON',
                              style: TextStyle(
                                color: seasonGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Text(
                          season.$1,
                          style: TextStyle(
                            color: impact.season == season.$1
                                ? Colors.white
                                : seasonGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          season.$2,
                          style: TextStyle(
                            color: impact.season == season.$1
                                ? seasonGold
                                : seasonGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          season.$3,
                          style: TextStyle(
                            color: impact.season == season.$1
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                _section(
                  'Flowering & food availability',
                  'Sri Lankan Department of Agriculture guidance describes regional honey-flow patterns, including February–March in wet-zone rubber-growing areas and June–September in many other areas. These are reference periods, not proof of flowering or food at this apiary. Record flowering plants, returning pollen, food stores and brood during local inspections.',
                  image: '03_flowering_plant',
                ),
                _section(
                  'From weather to colony observations',
                  'Compare rainfall and wind with observed flight activity. Record brood frames, colony strength, hive weight and food stores over time. Weather and calendar season alone cannot measure population or confirm healthy colony development.',
                  image: '04_beehive_in_garden',
                ),
                _section(
                  'Data confidence & local baseline',
                  'Weather source: WeatherAPI outdoor observations.\nObservation time: ${weather?.updatedAt ?? 'Unavailable'}\nLocation: $location\nSeason: calendar-based Sri Lankan reference.\nRegion: approximate coordinate-based context, not a verified climate-zone boundary.\nStation monthly climate baseline: not connected. No rainfall anomaly or long-term seasonal change is calculated.\nLocal flowering and colony measurements: use saved hive observations to verify conditions.\nThis screen shows the dashboard snapshot; return and refresh the dashboard for updated observations.',
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3EC),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Official Sri Lankan references',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: seasonGreen,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Climate seasons • Department of Census and Statistics, Statistical Abstract 2024',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SelectableText(
                        'https://www.statistics.gov.lk/abstract2024/chapter1',
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Beekeeping • Department of Agriculture',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SelectableText('https://doa.gov.lk/bee-keeping/'),
                      SizedBox(height: 14),
                      Text(
                        'Seasonal agro-meteorological advisories • Department of Agriculture',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SelectableText('https://doa.gov.lk/agro-met-advisory/'),
                      SizedBox(height: 14),
                      Text(
                        'Department of Meteorology • official observations and forecasts',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SelectableText('https://meteo.gov.lk/'),
                      SizedBox(height: 14),
                      Text(
                        'References checked 21 October 2026. Official advisories are available at the source; their live contents are not ingested by this app. Images are illustrative, not evidence from the selected hive.',
                        style: TextStyle(fontSize: 11, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
