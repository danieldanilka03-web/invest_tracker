import 'dart:math' as math;

import '../models/invest_radar.dart';
import 'analytics_service.dart';
import 'cash_service.dart';
import 'currency_service.dart';
import 'online_price_service.dart';
import 'online_settings_service.dart';
import 'radar_settings_service.dart';
import 'sector_service.dart';

class InvestRadarService {
  InvestRadarService._();

  static RadarSnapshot currentSnapshot() {
    final holdings = AnalyticsService.currentHoldings();
    final tickerValues = <String, double>{};
    final tickerQuantities = <String, double>{};
    final tickerSectors = <String, String>{};
    final tickerPricesRub = <String, double>{};
    final fallback = <String>{};

    holdings.forEach((ticker, holding) {
      tickerValues[ticker] = holding.valueRub;
      tickerQuantities[ticker] = holding.qty;
      tickerSectors[ticker] = SectorService.sectorFor(ticker);
      tickerPricesRub[ticker] = CurrencyService.toRub(holding.displayPrice, holding.currency);
      final online = OnlineSettingsService.enabled ? OnlinePriceService.get(ticker) : null;
      if (online == null || OnlinePriceService.ageOf(ticker)! > const Duration(hours: 24)) {
        fallback.add(ticker);
      }
    });

    return buildSnapshot(
      tickerValuesRub: tickerValues,
      tickerQuantities: tickerQuantities,
      tickerSectors: tickerSectors,
      tickerPricesRub: tickerPricesRub,
      cashRub: CashService.summary().cash,
      sectorTargets: RadarSettingsService.sectorTargets,
      tickerTargets: RadarSettingsService.tickerTargets,
      fallbackPriceTickers: fallback,
    );
  }

  static RadarSnapshot buildSnapshot({
    required Map<String, double> tickerValuesRub,
    required Map<String, double> tickerQuantities,
    required Map<String, String> tickerSectors,
    Map<String, double> tickerPricesRub = const {},
    double cashRub = 0,
    Map<String, double> sectorTargets = const {},
    Map<String, double> tickerTargets = const {},
    Set<String> fallbackPriceTickers = const {},
  }) {
    final cleanTickerValues = <String, double>{
      for (final entry in tickerValuesRub.entries)
        if (entry.value > 1e-6) entry.key.toUpperCase(): entry.value,
    };
    final cleanQuantities = <String, double>{
      for (final entry in tickerQuantities.entries) entry.key.toUpperCase(): math.max(0.0, entry.value),
    };
    final cleanSectors = <String, String>{
      for (final entry in tickerSectors.entries)
        entry.key.toUpperCase(): entry.value.trim().isEmpty ? 'Без сектора' : entry.value.trim(),
    };
    final cleanPrices = <String, double>{
      for (final entry in tickerPricesRub.entries) entry.key.toUpperCase(): entry.value,
    };
    final normalizedSectorTargets = RadarSettingsService.normalizeTargets(sectorTargets);
    final normalizedTickerTargets = RadarSettingsService.normalizeTargets(tickerTargets, uppercaseKeys: true);

    final sectorValues = <String, double>{};
    cleanTickerValues.forEach((ticker, value) {
      final sector = cleanSectors[ticker] ?? 'Без сектора';
      sectorValues[sector] = (sectorValues[sector] ?? 0) + value;
    });
    final total = cleanTickerValues.values.fold(0.0, (sum, value) => sum + value);

    final sectorDeviations = _deviations(
      level: RadarTargetLevel.sector,
      values: sectorValues,
      targets: normalizedSectorTargets,
      total: total,
    );
    final tickerDeviations = _deviations(
      level: RadarTargetLevel.ticker,
      values: cleanTickerValues,
      targets: normalizedTickerTargets,
      total: total,
    );

    final validSectors = _targetsAreValid(normalizedSectorTargets);
    final validTickers = _targetsAreValid(normalizedTickerTargets);
    final preliminary = !validSectors && !validTickers;
    final factors = _healthFactors(
      tickerValues: cleanTickerValues,
      sectorValues: sectorValues,
      total: total,
      deviations: validTickers ? tickerDeviations : (validSectors ? sectorDeviations : const []),
      fallbackCount: fallbackPriceTickers.where(cleanTickerValues.containsKey).length,
      preliminary: preliminary,
    );
    final score = (100 - factors.fold<double>(0, (sum, factor) => sum + factor.penalty))
        .round()
        .clamp(0, 100)
        .toInt();
    final recommendations = _recommendations(
      tickerDeviations: validTickers ? tickerDeviations : const [],
      sectorDeviations: validSectors ? sectorDeviations : const [],
      tickerValues: cleanTickerValues,
      sectorValues: sectorValues,
      total: total,
      fallbackTickers: fallbackPriceTickers,
      preliminary: preliminary,
    );

    return RadarSnapshot(
      securitiesValueRub: total,
      cashRub: math.max(0.0, cashRub),
      tickerValuesRub: Map.unmodifiable(cleanTickerValues),
      sectorValuesRub: Map.unmodifiable(sectorValues),
      tickerQuantities: Map.unmodifiable(cleanQuantities),
      tickerSectors: Map.unmodifiable(cleanSectors),
      tickerPricesRub: Map.unmodifiable(cleanPrices),
      fallbackPriceTickers: Set.unmodifiable(fallbackPriceTickers.map((e) => e.toUpperCase())),
      sectorDeviations: List.unmodifiable(sectorDeviations),
      tickerDeviations: List.unmodifiable(tickerDeviations),
      healthScore: score,
      healthIsPreliminary: preliminary,
      healthFactors: List.unmodifiable(factors),
      recommendations: List.unmodifiable(recommendations),
    );
  }

  static List<RadarDeviation> _deviations({
    required RadarTargetLevel level,
    required Map<String, double> values,
    required Map<String, double> targets,
    required double total,
  }) {
    final keys = {...values.keys, ...targets.keys};
    final result = <RadarDeviation>[];
    for (final key in keys) {
      final current = values[key] ?? 0;
      final currentPct = total > 0 ? current / total * 100 : 0.0;
      final targetPct = targets[key] ?? 0;
      final deviation = currentPct - targetPct;
      result.add(RadarDeviation(
        level: level,
        key: key,
        currentValueRub: current,
        currentPct: currentPct,
        targetPct: targetPct,
        deviationPct: deviation,
        amountToTargetRub: total * targetPct / 100 - current,
      ));
    }
    result.sort((a, b) => b.deviationPct.abs().compareTo(a.deviationPct.abs()));
    return result;
  }

  static bool _targetsAreValid(Map<String, double> targets) {
    if (targets.isEmpty) return false;
    final total = targets.values.fold(0.0, (sum, value) => sum + value);
    return (total - 100).abs() <= RadarSettingsService.targetTolerance;
  }

  static List<RadarHealthFactor> _healthFactors({
    required Map<String, double> tickerValues,
    required Map<String, double> sectorValues,
    required double total,
    required List<RadarDeviation> deviations,
    required int fallbackCount,
    required bool preliminary,
  }) {
    if (total <= 0) {
      return const [
        RadarHealthFactor(
          title: 'Нет позиций',
          explanation: 'Добавьте хотя бы одну сделку, чтобы радар оценил портфель.',
          penalty: 100,
          warning: true,
        ),
      ];
    }
    final factors = <RadarHealthFactor>[];
    final topTicker = tickerValues.values.reduce(math.max) / total * 100;
    final topSector = sectorValues.values.reduce(math.max) / total * 100;
    final tickerPenalty = ((topTicker - 25).clamp(0, 45).toDouble() / 45) * 28;
    final sectorPenalty = ((topSector - 45).clamp(0, 45).toDouble() / 45) * 18;
    factors.add(RadarHealthFactor(
      title: 'Концентрация бумаги',
      explanation: 'Крупнейшая позиция занимает ${topTicker.toStringAsFixed(1)}% портфеля.',
      penalty: tickerPenalty,
      warning: topTicker > 40,
    ));
    factors.add(RadarHealthFactor(
      title: 'Концентрация сектора',
      explanation: 'Крупнейший сектор занимает ${topSector.toStringAsFixed(1)}% портфеля.',
      penalty: sectorPenalty,
      warning: topSector > 60,
    ));
    if (!preliminary && deviations.isNotEmpty) {
      final weighted = deviations.fold<double>(0, (sum, d) => sum + d.deviationPct.abs()) / deviations.length;
      factors.add(RadarHealthFactor(
        title: 'Отклонение от целей',
        explanation: 'Среднее отклонение составляет ${weighted.toStringAsFixed(1)} п.п.',
        penalty: (weighted / 20 * 30).clamp(0, 30).toDouble(),
        warning: weighted > 10,
      ));
    }
    if (fallbackCount > 0) {
      final share = fallbackCount / tickerValues.length;
      factors.add(RadarHealthFactor(
        title: 'Качество цен',
        explanation: 'Для $fallbackCount из ${tickerValues.length} позиций используется не свежая биржевая цена.',
        penalty: (share * 16).clamp(0, 16).toDouble(),
        warning: true,
      ));
    }
    if (preliminary) {
      factors.add(const RadarHealthFactor(
        title: 'Цели не настроены',
        explanation: 'Оценка пока учитывает концентрацию и качество цен, но не ваш план распределения.',
        penalty: 6,
        warning: true,
      ));
    }
    return factors;
  }

  static List<RadarRecommendation> _recommendations({
    required List<RadarDeviation> tickerDeviations,
    required List<RadarDeviation> sectorDeviations,
    required Map<String, double> tickerValues,
    required Map<String, double> sectorValues,
    required double total,
    required Set<String> fallbackTickers,
    required bool preliminary,
  }) {
    if (total <= 0) return const [];
    final result = <RadarRecommendation>[];
    final deviations = tickerDeviations.isNotEmpty ? tickerDeviations : sectorDeviations;
    for (final d in deviations.where((e) => e.amountToTargetRub > total * 0.01).take(2)) {
      result.add(RadarRecommendation(
        kind: RadarActionKind.buy,
        key: d.key,
        title: 'Усилить ${d.key}',
        explanation: 'Сейчас ${d.currentPct.toStringAsFixed(1)}%, цель ${d.targetPct.toStringAsFixed(1)}%.',
        amountRub: d.amountToTargetRub,
        priority: 100 - result.length,
      ));
    }
    for (final d in deviations.where((e) => e.amountToTargetRub < -total * 0.01).take(1)) {
      result.add(RadarRecommendation(
        kind: RadarActionKind.reduce,
        key: d.key,
        title: 'Снизить долю ${d.key}',
        explanation: 'Сейчас ${d.currentPct.toStringAsFixed(1)}%, цель ${d.targetPct.toStringAsFixed(1)}%.',
        amountRub: -d.amountToTargetRub,
        priority: 80,
      ));
    }
    if (result.length < 3 && tickerValues.isNotEmpty) {
      final top = tickerValues.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final pct = top.value / total * 100;
      if (pct > 40 && result.every((r) => r.key != top.key)) {
        result.add(RadarRecommendation(
          kind: RadarActionKind.diversify,
          key: top.key,
          title: 'Проверить концентрацию ${top.key}',
          explanation: 'Одна бумага занимает ${pct.toStringAsFixed(1)}% портфеля. Сценарий продажи покажет эффект заранее.',
          priority: 70,
        ));
      }
    }
    if (result.length < 3 && fallbackTickers.isNotEmpty) {
      final ticker = fallbackTickers.firstWhere(tickerValues.containsKey, orElse: () => '');
      if (ticker.isNotEmpty) {
        result.add(RadarRecommendation(
          kind: RadarActionKind.updatePrice,
          key: ticker,
          title: 'Обновить цену $ticker',
          explanation: 'Радар использует резервную или устаревшую цену, поэтому доли могут отличаться от биржевых.',
          priority: 60,
        ));
      }
    }
    if (result.isEmpty && preliminary) {
      result.add(const RadarRecommendation(
        kind: RadarActionKind.configureTargets,
        key: '',
        title: 'Задать цели распределения',
        explanation: 'После настройки по секторам или бумагам радар рассчитает точные недовесы и перевесы.',
        priority: 50,
      ));
    }
    result.sort((a, b) => b.priority.compareTo(a.priority));
    return result.take(3).toList();
  }

  static RadarSimulationResult simulate({
    required RadarSnapshot before,
    required RadarTradeScenario scenario,
    Map<String, double> sectorTargets = const {},
    Map<String, double> tickerTargets = const {},
  }) {
    if (scenario.quantity <= 0 || scenario.priceRub <= 0) {
      throw ArgumentError('Количество и цена должны быть больше нуля.');
    }
    final ticker = scenario.ticker.trim().toUpperCase();
    if (ticker.isEmpty) {
      throw ArgumentError('Выберите бумагу для симуляции.');
    }
    final owned = before.tickerQuantities[ticker] ?? 0;
    if (scenario.kind == RadarTradeKind.sell && scenario.quantity > owned + 1e-9) {
      throw ArgumentError('Нельзя продать больше, чем есть в портфеле.');
    }
    final gross = scenario.quantity * scenario.priceRub;
    final deltaValue = scenario.kind == RadarTradeKind.buy ? gross : -gross;
    final values = Map<String, double>.from(before.tickerValuesRub);
    final quantities = Map<String, double>.from(before.tickerQuantities);
    values[ticker] = math.max(0.0, (values[ticker] ?? 0) + deltaValue);
    quantities[ticker] = math.max(0.0, owned + (scenario.kind == RadarTradeKind.buy ? scenario.quantity : -scenario.quantity));
    if (quantities[ticker]! <= 1e-9) {
      quantities.remove(ticker);
      values.remove(ticker);
    }
    final sectors = Map<String, String>.from(before.tickerSectors);
    sectors[ticker] = scenario.sector;
    final prices = Map<String, double>.from(before.tickerPricesRub);
    prices[ticker] = scenario.priceRub;
    final cashDelta = scenario.kind == RadarTradeKind.buy ? -(gross + scenario.feeRub) : gross - scenario.feeRub;
    final after = buildSnapshot(
      tickerValuesRub: values,
      tickerQuantities: quantities,
      tickerSectors: sectors,
      tickerPricesRub: prices,
      cashRub: math.max(0.0, before.cashRub + cashDelta),
      sectorTargets: sectorTargets,
      tickerTargets: tickerTargets,
      fallbackPriceTickers: before.fallbackPriceTickers,
    );
    return RadarSimulationResult(
      before: before,
      after: after,
      tradeAmountRub: gross + scenario.feeRub,
      healthDelta: after.healthScore - before.healthScore,
    );
  }

  static RadarAllocationPlan allocateNewMoney({
    required RadarSnapshot snapshot,
    required double amountRub,
    Map<String, double> sectorTargets = const {},
    Map<String, double> tickerTargets = const {},
  }) {
    if (!amountRub.isFinite || amountRub <= 0) {
      return RadarAllocationPlan(requestedRub: amountRub, error: 'Введите сумму больше нуля.');
    }
    final cleanSectors = RadarSettingsService.normalizeTargets(sectorTargets);
    final cleanTickers = RadarSettingsService.normalizeTargets(tickerTargets, uppercaseKeys: true);
    final validSectors = _targetsAreValid(cleanSectors);
    final validTickers = _targetsAreValid(cleanTickers);
    if (!validSectors && !validTickers) {
      return RadarAllocationPlan(
        requestedRub: amountRub,
        error: 'Сумма целей должна быть равна 100% хотя бы на одном уровне.',
      );
    }

    Map<String, double> shortagesFor(Map<String, double> values, Map<String, double> targets) {
      final futureTotal = snapshot.securitiesValueRub + amountRub;
      final shortages = <String, double>{};
      targets.forEach((key, pct) {
        final shortage = futureTotal * pct / 100 - (values[key] ?? 0);
        if (shortage > 0.5) shortages[key] = shortage;
      });
      return shortages;
    }

    final tickerShortages = validTickers ? shortagesFor(snapshot.tickerValuesRub, cleanTickers) : <String, double>{};
    final sectorShortages = validSectors ? shortagesFor(snapshot.sectorValuesRub, cleanSectors) : <String, double>{};
    final raw = <String, double>{};
    RadarTargetLevel level;

    if (validTickers) {
      level = RadarTargetLevel.ticker;
      if (validSectors) {
        for (final sectorEntry in sectorShortages.entries) {
          final candidates = tickerShortages.entries
              .where((entry) => snapshot.tickerSectors[entry.key] == sectorEntry.key)
              .toList();
          final totalTickerShortage = candidates.fold(0.0, (sum, entry) => sum + entry.value);
          if (totalTickerShortage <= 0) continue;
          for (final entry in candidates) {
            raw[entry.key] = (raw[entry.key] ?? 0) +
                math.min(sectorEntry.value, amountRub) * entry.value / totalTickerShortage;
          }
        }
      }
      if (raw.isEmpty) raw.addAll(tickerShortages);
    } else {
      level = RadarTargetLevel.sector;
      raw.addAll(sectorShortages);
    }

    if (raw.isEmpty) {
      return RadarAllocationPlan(
        requestedRub: amountRub,
        error: 'Портфель уже соответствует заданным целям для этой суммы.',
      );
    }
    final rawTotal = raw.values.fold(0.0, (sum, value) => sum + value);
    final scale = math.min(1.0, amountRub / rawTotal);
    final rounded = <String, double>{};
    raw.forEach((key, value) => rounded[key] = (value * scale).roundToDouble());
    var allocated = rounded.values.fold(0.0, (sum, value) => sum + value);
    final largest = raw.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    rounded[largest] = math.max(0.0, (rounded[largest] ?? 0) + amountRub.roundToDouble() - allocated);
    allocated = rounded.values.fold(0.0, (sum, value) => sum + value);
    if (allocated <= 0) {
      return RadarAllocationPlan(requestedRub: amountRub, error: 'Сумма слишком мала для распределения.');
    }
    final items = rounded.entries
        .where((entry) => entry.value > 0)
        .map((entry) => RadarAllocationItem(
              level: level,
              key: entry.key,
              amountRub: entry.value,
              shortageRub: raw[entry.key] ?? entry.value,
              explanation: 'Направить в недовес относительно целевой доли.',
            ))
        .toList()
      ..sort((a, b) => b.amountRub.compareTo(a.amountRub));
    return RadarAllocationPlan(requestedRub: amountRub, items: items);
  }
}
