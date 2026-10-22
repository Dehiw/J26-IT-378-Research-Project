import '../models/apiary_model.dart';
import 'apiary_service.dart';
import 'environment_fallback.dart';

class EnvironmentCatalog {
  static Future<List<ApiaryModel>> apiaries(ApiaryService service) async {
    final payload = await EnvironmentFallback.instance.read(
      'catalog/apiaries',
      () async => {
        'apiaries': (await service.fetchApiaries())
            .map((a) => a.toJson())
            .toList(),
      },
      'apiaries',
    );
    return (payload['apiaries'] as List)
        .map((a) => ApiaryModel.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList();
  }

  static Future<List<HiveModel>> hives(
    ApiaryService service,
    String apiaryId,
  ) async {
    final payload = await EnvironmentFallback.instance.read(
      'catalog/hives/$apiaryId',
      () async => {
        'hives': (await service.fetchHives(apiaryId))
            .map((h) => h.toJson())
            .toList(),
      },
      'hives',
      demoOnly: isDemoId(apiaryId),
    );
    final selected = dataSource(payload) == 'demo'
        ? await EnvironmentFallback.instance.selectedDemoHive()
        : null;
    final items = (payload['hives'] as List)
        .map((h) => HiveModel.fromJson(Map<String, dynamic>.from(h as Map)))
        .toList();
    if (selected != null) {
      items.sort(
        (a, b) => a.id == selected
            ? -1
            : b.id == selected
            ? 1
            : 0,
      );
    }
    return items;
  }
}
