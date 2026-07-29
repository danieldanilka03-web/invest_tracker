import 'package:flutter_test/flutter_test.dart';
import 'package:invest_tracker/models/invest_radar.dart';
import 'package:invest_tracker/services/invest_radar_service.dart';

void main() {
  const sectors = {'SBER': 'Финансы', 'GAZP': 'Нефть и газ'};

  RadarSnapshot snapshot({
    Map<String, double> values = const {'SBER': 80000, 'GAZP': 20000},
    Map<String, double> quantities = const {'SBER': 100, 'GAZP': 100},
    Map<String, double> sectorTargets = const {'Финансы': 50, 'Нефть и газ': 50},
    Map<String, double> tickerTargets = const {'SBER': 50, 'GAZP': 50},
  }) {
    return InvestRadarService.buildSnapshot(
      tickerValuesRub: values,
      tickerQuantities: quantities,
      tickerSectors: sectors,
      tickerPricesRub: const {'SBER': 800, 'GAZP': 200},
      sectorTargets: sectorTargets,
      tickerTargets: tickerTargets,
    );
  }

  test('detects concentration and target deviations', () {
    final result = snapshot();

    expect(result.healthIsPreliminary, isFalse);
    expect(result.tickerDeviations.first.key, 'SBER');
    expect(result.tickerDeviations.first.deviationPct, closeTo(30, 0.001));
    expect(result.recommendations, isNotEmpty);
  });

  test('marks score preliminary without complete targets', () {
    final result = snapshot(sectorTargets: const {}, tickerTargets: const {});

    expect(result.healthIsPreliminary, isTrue);
    expect(result.healthFactors.any((factor) => factor.title == 'Цели не настроены'), isTrue);
  });

  test('buy simulation changes portfolio without mutating original', () {
    final before = snapshot();
    final result = InvestRadarService.simulate(
      before: before,
      scenario: const RadarTradeScenario(
        kind: RadarTradeKind.buy,
        ticker: 'GAZP',
        sector: 'Нефть и газ',
        quantity: 100,
        priceRub: 200,
      ),
      sectorTargets: const {'Финансы': 50, 'Нефть и газ': 50},
      tickerTargets: const {'SBER': 50, 'GAZP': 50},
    );

    expect(before.tickerValuesRub['GAZP'], 20000);
    expect(result.after.tickerValuesRub['GAZP'], 40000);
    expect(result.after.securitiesValueRub, 120000);
  });

  test('sell simulation rejects quantity above holding', () {
    final before = snapshot();

    expect(
      () => InvestRadarService.simulate(
        before: before,
        scenario: const RadarTradeScenario(
          kind: RadarTradeKind.sell,
          ticker: 'GAZP',
          sector: 'Нефть и газ',
          quantity: 101,
          priceRub: 200,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('allocates all new money to positive shortages', () {
    final result = InvestRadarService.allocateNewMoney(
      snapshot: snapshot(),
      amountRub: 20000,
      sectorTargets: const {'Финансы': 50, 'Нефть и газ': 50},
      tickerTargets: const {'SBER': 50, 'GAZP': 50},
    );

    expect(result.isValid, isTrue);
    expect(result.items.fold<double>(0, (sum, item) => sum + item.amountRub), 20000);
    expect(result.items.single.key, 'GAZP');
  });

  test('requires targets summing to one hundred', () {
    final result = InvestRadarService.allocateNewMoney(
      snapshot: snapshot(sectorTargets: const {}, tickerTargets: const {}),
      amountRub: 10000,
      sectorTargets: const {'Финансы': 40},
    );

    expect(result.error, isNotNull);
  });
}
