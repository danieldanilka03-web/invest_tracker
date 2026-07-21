import 'dart:math' as math;
import '../models/purchase.dart';
import '../models/income.dart';
import 'storage_service.dart';
import 'currency_service.dart';

/// Фильтр периода для статистики
enum PeriodFilter { month1, month3, month6, year1, all }

/// Текущая позиция по бумаге: количество, средняя цена входа, последняя цена сделки,
/// стоимость сейчас и прибыль/убыток (в рублях — базовой валюте статистики)
class HoldingInfo {
  final double qty;
  final double avgCost;
  final double lastPrice;
  final String currency;
  final double costBasisRub;
  final double valueRub;

  HoldingInfo({
    required this.qty,
    required this.avgCost,
    required this.lastPrice,
    required this.currency,
    required this.costBasisRub,
    required this.valueRub,
  });

  double get pnlRub => valueRub - costBasisRub;
  double get pnlPct => costBasisRub == 0 ? 0 : (pnlRub / costBasisRub) * 100;
}

class AnalyticsService {
  static DateTime? _periodStart(PeriodFilter f) {
    final now = DateTime.now();
    switch (f) {
      case PeriodFilter.month1:
        return DateTime(now.year, now.month - 1, now.day);
      case PeriodFilter.month3:
        return DateTime(now.year, now.month - 3, now.day);
      case PeriodFilter.month6:
        return DateTime(now.year, now.month - 6, now.day);
      case PeriodFilter.year1:
        return DateTime(now.year - 1, now.month, now.day);
      case PeriodFilter.all:
        return null;
    }
  }

  static List<Purchase> filterPurchases(PeriodFilter f, {AssetType? type, String? sector}) {
    final start = _periodStart(f);
    return StorageService.purchases.where((p) {
      final okDate = start == null || p.date.isAfter(start);
      final okType = type == null || p.type == type;
      final okSector = sector == null || p.sector == sector;
      return okDate && okType && okSector;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static List<Income> filterIncomes(PeriodFilter f, {IncomeType? type}) {
    final start = _periodStart(f);
    return StorageService.incomes.where((i) {
      final okDate = start == null || i.date.isAfter(start);
      final okType = type == null || i.type == type;
      return okDate && okType;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static double totalInvested({PeriodFilter f = PeriodFilter.all}) {
    double sum = 0;
    for (final p in filterPurchases(f)) {
      final amountRub = CurrencyService.toRub(p.quantity * p.pricePerUnit + p.fee, p.currency);
      sum += p.isSell ? -amountRub : amountRub;
    }
    return sum;
  }

  static double totalIncome({PeriodFilter f = PeriodFilter.all}) {
    double sum = 0;
    for (final i in filterIncomes(f)) {
      sum += CurrencyService.toRub(i.amountNet, i.currency);
    }
    return sum;
  }

  static Map<AssetType, double> investedByType({PeriodFilter f = PeriodFilter.all}) {
    final map = <AssetType, double>{};
    for (final p in filterPurchases(f)) {
      final amount = CurrencyService.toRub(p.total, p.currency);
      map[p.type] = (map[p.type] ?? 0) + (p.isSell ? -amount : amount);
    }
    map.removeWhere((_, v) => v <= 0);
    return map;
  }

  static Map<String, double> investedBySector({PeriodFilter f = PeriodFilter.all}) {
    final map = <String, double>{};
    for (final p in filterPurchases(f)) {
      final key = p.sector?.isNotEmpty == true ? p.sector! : 'Без сектора';
      final amount = CurrencyService.toRub(p.total, p.currency);
      map[key] = (map[key] ?? 0) + (p.isSell ? -amount : amount);
    }
    map.removeWhere((_, v) => v <= 0);
    return map;
  }

  static Map<String, double> incomeByMonth({PeriodFilter f = PeriodFilter.year1}) {
    final map = <String, double>{};
    for (final i in filterIncomes(f)) {
      final key = '${i.date.year}-${i.date.month.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + CurrencyService.toRub(i.amountNet, i.currency);
    }
    return map;
  }

  static Map<String, HoldingInfo> currentHoldings() {
    final purchases = [...StorageService.purchases]..sort((a, b) => a.date.compareTo(b.date));

    final qty = <String, double>{};
    final costBasis = <String, double>{};
    final lastPrice = <String, double>{};
    final currencyOf = <String, String>{};

    for (final p in purchases) {
      final t = p.ticker;
      qty.putIfAbsent(t, () => 0);
      costBasis.putIfAbsent(t, () => 0);
      currencyOf[t] = p.currency;
      lastPrice[t] = p.pricePerUnit;

      if (p.isSell) {
        final curQty = qty[t]!;
        if (curQty > 0) {
          final avgCostPerUnit = costBasis[t]! / curQty;
          final sellQty = p.quantity > curQty ? curQty : p.quantity;
          costBasis[t] = costBasis[t]! - sellQty * avgCostPerUnit;
        }
        final newQty = curQty - p.quantity;
        qty[t] = newQty < 0 ? 0 : newQty;
      } else {
        costBasis[t] = costBasis[t]! + p.quantity * p.pricePerUnit + p.fee;
        qty[t] = qty[t]! + p.quantity;
      }
    }

    final result = <String, HoldingInfo>{};
    qty.forEach((ticker, q) {
      if (q <= 1e-9) return;
      final cur = currencyOf[ticker] ?? 'RUB';
      final avgCost = costBasis[ticker]! / q;
      final price = lastPrice[ticker] ?? avgCost;
      result[ticker] = HoldingInfo(
        qty: q,
        avgCost: avgCost,
        lastPrice: price,
        currency: cur,
        costBasisRub: CurrencyService.toRub(costBasis[ticker]!, cur),
        valueRub: CurrencyService.toRub(q * price, cur),
      );
    });
    return result;
  }

  static double currentPortfolioValueRub() =>
      currentHoldings().values.fold(0.0, (s, h) => s + h.valueRub);

  static double totalUnrealizedPnlRub() =>
      currentHoldings().values.fold(0.0, (s, h) => s + h.pnlRub);

  static double topHoldingConcentrationPct() {
    final holdings = currentHoldings();
    if (holdings.isEmpty) return 0;
    final total = holdings.values.fold(0.0, (s, h) => s + h.valueRub);
    if (total <= 0) return 0;
    final maxValue = holdings.values.map((h) => h.valueRub).reduce((a, b) => a > b ? a : b);
    return (maxValue / total) * 100;
  }

  static String? topHoldingTicker() {
    final holdings = currentHoldings();
    if (holdings.isEmpty) return null;
    String? best;
    double bestValue = -1;
    holdings.forEach((ticker, h) {
      if (h.valueRub > bestValue) {
        bestValue = h.valueRub;
        best = ticker;
      }
    });
    return best;
  }

  static List<MapEntry<DateTime, double>> portfolioValueTimeline() {
    final purchases = [...StorageService.purchases]..sort((a, b) => a.date.compareTo(b.date));
    if (purchases.isEmpty) return [];

    final qty = <String, double>{};
    final lastPrice = <String, double>{};
    final currencyOf = <String, String>{};
    final points = <MapEntry<DateTime, double>>[];

    for (final p in purchases) {
      final newQty = (qty[p.ticker] ?? 0) + p.signedQuantity;
      qty[p.ticker] = newQty < 0 ? 0 : newQty;
      lastPrice[p.ticker] = p.pricePerUnit;
      currencyOf[p.ticker] = p.currency;

      double total = 0;
      qty.forEach((ticker, q) {
        final price = lastPrice[ticker] ?? 0;
        total += CurrencyService.toRub(q * price, currencyOf[ticker] ?? 'RUB');
      });
      points.add(MapEntry(p.date, total));
    }
    return points;
  }

  static List<({DateTime date, double price, bool isSell})> priceHistoryForTicker(String ticker) {
    final list = StorageService.purchases
        .where((p) => p.ticker == ticker)
        .map((p) => (date: p.date, price: p.pricePerUnit, isSell: p.isSell))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  static List<String> allOwnedTickers() {
    final set = <String>{};
    for (final p in StorageService.purchases) {
      set.add(p.ticker);
    }
    final list = set.toList()..sort();
    return list;
  }

  static double? xirrPercent() {
    final flows = <MapEntry<DateTime, double>>[];

    for (final p in StorageService.purchases) {
      final amountRub = CurrencyService.toRub(p.quantity * p.pricePerUnit + p.fee, p.currency);
      flows.add(MapEntry(p.date, p.isSell ? amountRub : -amountRub));
    }
    for (final i in StorageService.incomes) {
      flows.add(MapEntry(i.date, CurrencyService.toRub(i.amountNet, i.currency)));
    }

    final currentValue = currentPortfolioValueRub();
    if (currentValue > 0) {
      flows.add(MapEntry(DateTime.now(), currentValue));
    }

    if (flows.length < 2) return null;
    flows.sort((a, b) => a.key.compareTo(b.key));

    final t0 = flows.first.key;
    double npv(double rate) {
      double sum = 0;
      for (final f in flows) {
        final years = f.key.difference(t0).inDays / 365.0;
        final base = 1 + rate;
        if (base <= 0) return double.nan;
        sum += f.value / math.pow(base, years);
      }
      return sum;
    }

    double lo = -0.99;
    double hi = 3.0;
    double npvLo = npv(lo);
    final npvHi = npv(hi);
    if (npvLo.isNaN || npvHi.isNaN) return null;
    if (npvLo * npvHi > 0) return null;

    double mid = 0;
    for (int i = 0; i < 60; i++) {
      mid = (lo + hi) / 2;
      final npvMid = npv(mid);
      if (npvMid.abs() < 1e-6) break;
      if (npvLo * npvMid < 0) {
        hi = mid;
      } else {
        lo = mid;
        npvLo = npvMid;
      }
    }
    return mid * 100;
  }
}
