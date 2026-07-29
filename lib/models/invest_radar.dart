enum RadarTargetLevel { sector, ticker }

enum RadarActionKind { buy, reduce, diversify, updatePrice, configureTargets }

enum RadarTradeKind { buy, sell }

class RadarDeviation {
  final RadarTargetLevel level;
  final String key;
  final double currentValueRub;
  final double currentPct;
  final double targetPct;
  final double deviationPct;
  final double amountToTargetRub;

  const RadarDeviation({
    required this.level,
    required this.key,
    required this.currentValueRub,
    required this.currentPct,
    required this.targetPct,
    required this.deviationPct,
    required this.amountToTargetRub,
  });
}

class RadarHealthFactor {
  final String title;
  final String explanation;
  final double penalty;
  final bool warning;

  const RadarHealthFactor({
    required this.title,
    required this.explanation,
    required this.penalty,
    this.warning = false,
  });
}

class RadarRecommendation {
  final RadarActionKind kind;
  final String key;
  final String title;
  final String explanation;
  final double? amountRub;
  final int priority;

  const RadarRecommendation({
    required this.kind,
    required this.key,
    required this.title,
    required this.explanation,
    this.amountRub,
    required this.priority,
  });
}

class RadarSnapshot {
  final double securitiesValueRub;
  final double cashRub;
  final Map<String, double> tickerValuesRub;
  final Map<String, double> sectorValuesRub;
  final Map<String, double> tickerQuantities;
  final Map<String, String> tickerSectors;
  final Map<String, double> tickerPricesRub;
  final Set<String> fallbackPriceTickers;
  final List<RadarDeviation> sectorDeviations;
  final List<RadarDeviation> tickerDeviations;
  final int healthScore;
  final bool healthIsPreliminary;
  final List<RadarHealthFactor> healthFactors;
  final List<RadarRecommendation> recommendations;

  const RadarSnapshot({
    required this.securitiesValueRub,
    required this.cashRub,
    required this.tickerValuesRub,
    required this.sectorValuesRub,
    required this.tickerQuantities,
    required this.tickerSectors,
    required this.tickerPricesRub,
    required this.fallbackPriceTickers,
    required this.sectorDeviations,
    required this.tickerDeviations,
    required this.healthScore,
    required this.healthIsPreliminary,
    required this.healthFactors,
    required this.recommendations,
  });
}

class RadarTradeScenario {
  final RadarTradeKind kind;
  final String ticker;
  final String sector;
  final double quantity;
  final double priceRub;
  final double feeRub;

  const RadarTradeScenario({
    required this.kind,
    required this.ticker,
    required this.sector,
    required this.quantity,
    required this.priceRub,
    this.feeRub = 0,
  });
}

class RadarSimulationResult {
  final RadarSnapshot before;
  final RadarSnapshot after;
  final double tradeAmountRub;
  final int healthDelta;

  const RadarSimulationResult({
    required this.before,
    required this.after,
    required this.tradeAmountRub,
    required this.healthDelta,
  });
}

class RadarAllocationItem {
  final RadarTargetLevel level;
  final String key;
  final double amountRub;
  final double shortageRub;
  final String explanation;

  const RadarAllocationItem({
    required this.level,
    required this.key,
    required this.amountRub,
    required this.shortageRub,
    required this.explanation,
  });
}

class RadarAllocationPlan {
  final double requestedRub;
  final List<RadarAllocationItem> items;
  final String? error;

  const RadarAllocationPlan({
    required this.requestedRub,
    this.items = const [],
    this.error,
  });

  bool get isValid => error == null && items.isNotEmpty;
}
