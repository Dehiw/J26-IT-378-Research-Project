import 'package:frontend/utils/acoustic/acoustic_strings.dart';
import 'package:frontend/models/acoustic/hive_option.dart';

/// Display names for hives, keyed by id. Results, recordings and history
/// only store a hive id, so they look the name up here.
///
/// The Monitor fills this from [AcousticService.getHives] each time it
/// loads. An id that was never registered shows as "Hive" followed by the id.
class HiveNames {
  HiveNames._();

  static final Map<String, String> _names = {};

  /// Registers the names in [hives], replacing any earlier name for the
  /// same id.
  static void remember(Iterable<HiveOption> hives) {
    for (final hive in hives) {
      _names[hive.id] = hive.name;
    }
  }

  /// The name for [hiveId], such as "Hive H-001".
  static String of(String hiveId) =>
      _names[hiveId] ?? AcousticStrings.hiveName(hiveId);

  /// Forgets every name. Used by tests.
  static void clear() => _names.clear();
}
