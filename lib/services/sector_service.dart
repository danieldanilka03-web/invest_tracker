import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/securities.dart';

/// Пользовательские секторы и привязка ценных бумаг к ним.
/// У одной бумаги может быть только один сектор. Если бумага не привязана
/// вручную, используется сектор из встроенного справочника (если есть),
/// иначе — "Без сектора".
class SectorService {
  static const boxName = 'sectors';
  static const _listKey = '_custom_list';
  static late Box<String> _box; // _custom_list -> JSON-массив имён секторов; TICKER -> имя сектора

  static final ValueNotifier<int> version = ValueNotifier(0);

  static Future<void> init() async {
    _box = await Hive.openBox<String>(boxName);
  }

  static List<String> get customSectors {
    final raw = _box.get(_listKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  static Future<void> addSector(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final list = customSectors;
    if (list.contains(trimmed)) return;
    list.add(trimmed);
    await _box.put(_listKey, jsonEncode(list));
    version.value++;
  }

  static Future<void> removeSector(String name) async {
    final list = customSectors..remove(name);
    await _box.put(_listKey, jsonEncode(list));
    // отвязываем все бумаги, у которых был этот сектор
    for (final key in _box.keys.toList()) {
      if (key == _listKey) continue;
      if (_box.get(key) == name) await _box.delete(key);
    }
    version.value++;
  }

  /// Все секторы, доступные для выбора: пользовательские + встречающиеся
  /// во встроенном справочнике (без дублей)
  static List<String> get allAvailableSectors {
    final set = <String>{...customSectors};
    for (final s in SecuritiesDatabase.all) {
      if (s.sector.isNotEmpty) set.add(s.sector);
    }
    final list = set.toList()..sort();
    return list;
  }

  static Future<void> assignSector(String ticker, String? sector) async {
    final key = ticker.toUpperCase();
    if (sector == null || sector.isEmpty) {
      await _box.delete(key);
    } else {
      await _box.put(key, sector);
    }
    version.value++;
  }

  /// Итоговый сектор бумаги: ручная привязка > справочник > "Без сектора"
  static String sectorFor(String ticker) {
    final manual = _box.get(ticker.toUpperCase());
    if (manual != null && manual.isNotEmpty) return manual;
    final fromDb = SecuritiesDatabase.byTicker(ticker)?.sector;
    if (fromDb != null && fromDb.isNotEmpty) return fromDb;
    return 'Без сектора';
  }

  static String? manualSectorFor(String ticker) => _box.get(ticker.toUpperCase());

  /// Все ручные привязки тикер -> сектор (для бэкапа)
  static Map<String, String> get allAssignments {
    final map = <String, String>{};
    for (final key in _box.keys) {
      if (key == _listKey) continue;
      final value = _box.get(key);
      if (value != null) map[key as String] = value;
    }
    return map;
  }
}
