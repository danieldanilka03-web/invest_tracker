import 'package:flutter_test/flutter_test.dart';
import 'package:invest_tracker/services/radar_settings_service.dart';

void main() {
  test('normalizes keys and percentages', () {
    final result = RadarSettingsService.normalizeTargets(
      const {' sber ': 40, 'GAZP': 120, '': 25, 'ZERO': 0},
      uppercaseKeys: true,
    );

    expect(result, {'SBER': 40, 'GAZP': 100});
  });

  test('encodes and decodes versioned target json', () {
    const targets = RadarTargets(
      sectorTargets: {'Финансы': 60, 'IT': 40},
      tickerTargets: {'sber': 60, 'ydex': 40},
    );

    final decoded = RadarSettingsService.decodeTargets(
      RadarSettingsService.encodeTargets(targets),
    );

    expect(decoded.sectorTargets, {'Финансы': 60, 'IT': 40});
    expect(decoded.tickerTargets, {'SBER': 60, 'YDEX': 40});
    expect(decoded.hasValidSectorTargets, isTrue);
    expect(decoded.hasValidTickerTargets, isTrue);
  });

  test('uses a separate box name for every non-default portfolio', () {
    expect(RadarSettingsService.boxNameFor('default'), 'radar_targets');
    expect(RadarSettingsService.boxNameFor('portfolio-a'), 'radar_targets_portfolio-a');
    expect(RadarSettingsService.boxNameFor('portfolio-b'), isNot(RadarSettingsService.boxNameFor('portfolio-a')));
  });

  test('incomplete targets remain readable but invalid for rebalancing', () {
    const targets = RadarTargets(sectorTargets: {'Финансы': 70});

    expect(targets.sectorTotal, 70);
    expect(targets.hasValidSectorTargets, isFalse);
  });
}
