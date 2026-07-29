import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'portfolio_service.dart';

class RadarTargets {
  final Map<String, double> sectorTargets;
  final Map<String, double> tickerTargets;

  const RadarTargets({
    this.sectorTargets = const {},
    this.tickerTargets = const {},
  });

  double get sectorTotal => sectorTargets.values.fold(0.0, (sum, value) => sum + value);
  double get tickerTotal => tickerTargets.values.fold(0.0, (sum, value) => sum + value);

  bool get hasValidSectorTargets =>
      sectorTargets.isNotEmpty && (sectorTotal - 100).abs() <= RadarSettingsService.targetTolerance;
  bool get hasValidTickerTargets =>
      tickerTargets.isNotEmpty && (tickerTotal - 100).abs() <= RadarSettingsService.targetTolerance;
}

class RadarSettingsService {
  RadarSettingsService._();

  static const targetTolerance = 0.05;
  static const _dataKey = '_targets';
  static late Box<String> _box;

  static final ValueNotifier<int> version = ValueNotifier(0);

  static String boxNameFor(String portfolioId) =>
      portfolioId == PortfolioService.defaultId ? 'radar_targets' : 'radar_targets_$portfolioId';

  static Future<void> init() async {
    _box = await Hive.openBox<String>(boxNameFor(PortfolioService.activeId));
  }

  static Future<void> reopenBoxFor(String portfolioId) async {
    await _box.close();
    _box = await Hive.openBox<String>(boxNameFor(portfolioId));
    version.value++;
  }

  static Future<void> deleteBoxFor(String portfolioId) async {
    final name = boxNameFor(portfolioId);
    if (Hive.isBoxOpen(name)) {
      await Hive.box<String>(name).close();
    }
    await Hive.deleteBoxFromDisk(name);
  }

  static RadarTargets get targets {
    final raw = _box.get(_dataKey);
    if (raw == null) return const RadarTargets();
    try {
      return decodeTargets(raw);
    } catch (_) {
      return const RadarTargets();
    }
  }

  static Map<String, double> get sectorTargets => Map.unmodifiable(targets.sectorTargets);
  static Map<String, double> get tickerTargets => Map.unmodifiable(targets.tickerTargets);

  static Future<void> save({
    required Map<String, double> sectorTargets,
    required Map<String, double> tickerTargets,
  }) async {
    final normalized = RadarTargets(
      sectorTargets: normalizeTargets(sectorTargets),
      tickerTargets: normalizeTargets(tickerTargets, uppercaseKeys: true),
    );
    await _box.put(_dataKey, encodeTargets(normalized));
    version.value++;
  }

  static Future<void> clear() async {
    await _box.delete(_dataKey);
    version.value++;
  }

  static Map<String, double> normalizeTargets(
    Map<String, double> values, {
    bool uppercaseKeys = false,
  }) {
    final result = <String, double>{};
    for (final entry in values.entries) {
      var key = entry.key.trim();
      if (uppercaseKeys) key = key.toUpperCase();
      if (key.isEmpty || !entry.value.isFinite) continue;
      final value = entry.value.clamp(0, 100).toDouble();
      if (value <= 0) continue;
      result[key] = value;
    }
    return result;
  }

  static String encodeTargets(RadarTargets value) => jsonEncode({
        'version': 1,
        'sectorTargets': value.sectorTargets,
        'tickerTargets': value.tickerTargets,
      });

  static RadarTargets decodeTargets(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    Map<String, double> readMap(Object? source, {bool uppercaseKeys = false}) {
      if (source is! Map) return {};
      final values = <String, double>{};
      for (final entry in source.entries) {
        final number = entry.value;
        if (number is num) values['${entry.key}'] = number.toDouble();
      }
      return normalizeTargets(values, uppercaseKeys: uppercaseKeys);
    }

    return RadarTargets(
      sectorTargets: readMap(json['sectorTargets']),
      tickerTargets: readMap(json['tickerTargets'], uppercaseKeys: true),
    );
  }
}
