import 'package:flutter/material.dart';

import '../design/format.dart';
import '../design/motion.dart';
import '../design/surfaces.dart';
import '../design/tokens.dart';
import '../models/invest_radar.dart';
import '../services/invest_radar_service.dart';
import '../services/manual_price_service.dart';
import '../services/online_price_service.dart';
import '../services/portfolio_service.dart';
import '../services/radar_settings_service.dart';
import '../services/sector_service.dart';
import '../services/storage_service.dart';
import '../widgets/security_picker_field.dart';
import 'home_screen.dart';

class InvestRadarScreen extends StatefulWidget {
  const InvestRadarScreen({super.key});

  @override
  State<InvestRadarScreen> createState() => _InvestRadarScreenState();
}

class _InvestRadarScreenState extends State<InvestRadarScreen> {
  RadarTargetLevel _level = RadarTargetLevel.sector;

  late final List<ValueNotifier<int>> _notifiers;

  @override
  void initState() {
    super.initState();
    _notifiers = [
      StorageService.dataVersion,
      RadarSettingsService.version,
      SectorService.version,
      ManualPriceService.version,
      OnlinePriceService.version,
      PortfolioService.version,
    ];
    for (final notifier in _notifiers) {
      notifier.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final notifier in _notifiers) {
      notifier.removeListener(_refresh);
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = InvestRadarService.currentSnapshot();
    final accent = context.accent;
    if (snapshot.securitiesValueRub <= 0) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AuroraBackground(
          profit: 0,
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, kListBottomPadding),
              children: [
                _header(context),
                const SizedBox(height: 60),
                EmptyState(
                  icon: Icons.radar_rounded,
                  title: 'Радар ждёт первую позицию',
                  subtitle: 'Добавьте сделку, и здесь появятся оценка здоровья, риски и сценарии ребалансировки.',
                  action: GradientButton(
                    label: 'Перейти к сделкам',
                    icon: Icons.swap_horiz_rounded,
                    expand: false,
                    onPressed: () => HomeScreen.goToPurchases(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final deviations = _level == RadarTargetLevel.sector
        ? snapshot.sectorDeviations
        : snapshot.tickerDeviations;
    int step = 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        profit: snapshot.healthScore - 60,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            physics: const BouncingScrollPhysics(),
            children: [
              _header(context),
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * step++),
                child: GlassCard(
                  glow: _scoreColor(snapshot.healthScore),
                  child: Row(
                    children: [
                      _ScoreRing(score: snapshot.healthScore),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _scoreTitle(snapshot.healthScore),
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (snapshot.healthIsPreliminary)
                                  TagChip(text: 'предварительно', color: AppColors.gold),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              snapshot.healthFactors.where((f) => f.warning).map((f) => f.explanation).take(2).join(' '),
                              style: TextStyle(fontSize: 12, height: 1.42, color: context.dim),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * step++),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      title: 'Что требует внимания',
                      subtitle: 'До трёх наиболее значимых действий прямо сейчас',
                    ),
                    if (snapshot.recommendations.isEmpty)
                      InfoBanner(
                        text: 'Критичных отклонений не найдено. Портфель близок к заданному плану.',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.positive,
                      )
                    else
                      ...snapshot.recommendations.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecommendationCard(recommendation: r),
                          )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * step++),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      title: 'Факт и цель',
                      subtitle: 'Отклонение текущей структуры от вашего плана',
                      trailing: IconButton(
                        tooltip: 'Настроить цели',
                        icon: const Icon(Icons.tune_rounded),
                        onPressed: () => _showTargetsEditor(context),
                      ),
                    ),
                    PillTabs<RadarTargetLevel>(
                      values: RadarTargetLevel.values,
                      selected: _level,
                      labelOf: (v) => v == RadarTargetLevel.sector ? 'Секторы' : 'Бумаги',
                      onChanged: (value) => setState(() => _level = value),
                    ),
                    const SizedBox(height: 12),
                    if (deviations.where((d) => d.targetPct > 0).isEmpty)
                      InfoBanner(
                        text: 'Для этого уровня цели ещё не настроены.',
                        icon: Icons.track_changes_rounded,
                        color: AppColors.info,
                        onTap: () => _showTargetsEditor(context),
                      )
                    else
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: deviations
                              .where((d) => d.targetPct > 0 || d.currentPct > 0)
                              .take(10)
                              .map((d) => _DeviationRow(deviation: d))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * step++),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(title: 'Попробовать сценарий'),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.compare_arrows_rounded,
                            title: 'Сделка',
                            subtitle: 'Покупка или продажа',
                            color: accent,
                            onTap: () => _showTradeSimulator(context, snapshot),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionCard(
                            icon: Icons.call_split_rounded,
                            title: 'Новая сумма',
                            subtitle: 'Разложить по недовесам',
                            color: AppColors.violet,
                            onTap: () => _showAllocation(context, snapshot),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GradientButton(
                      label: 'Настроить цели распределения',
                      icon: Icons.track_changes_rounded,
                      onPressed: () => _showTargetsEditor(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kListBottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradient.accent(context.accent),
              boxShadow: [BoxShadow(color: context.accent.withOpacity(0.3), blurRadius: 16)],
            ),
            child: const Icon(Icons.radar_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ИНВЕСТ-РАДАР', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: context.dim, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(PortfolioService.active.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Настроить цели',
            icon: const Icon(Icons.settings_suggest_outlined),
            onPressed: () => _showTargetsEditor(context),
          ),
        ],
      );

  Future<void> _showTargetsEditor(BuildContext context) async {
    await showAppSheet<void>(
      context: context,
      builder: (ctx) => _TargetsEditor(onSaved: _refresh),
    );
  }

  Future<void> _showTradeSimulator(BuildContext context, RadarSnapshot snapshot) async {
    await showAppSheet<void>(
      context: context,
      builder: (ctx) => _TradeSimulator(snapshot: snapshot),
    );
  }

  Future<void> _showAllocation(BuildContext context, RadarSnapshot snapshot) async {
    await showAppSheet<void>(
      context: context,
      builder: (ctx) => _AllocationSheet(snapshot: snapshot),
    );
  }

  Color _scoreColor(int score) => score >= 75
      ? AppColors.positive
      : score >= 50
          ? AppColors.gold
          : AppColors.negative;

  String _scoreTitle(int score) => score >= 75
      ? 'Портфель в форме'
      : score >= 50
          ? 'Есть что улучшить'
          : 'Нужна проверка рисков';
}

class _ScoreRing extends StatelessWidget {
  final int score;
  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 75
        ? AppColors.positive
        : score >= 50
            ? AppColors.gold
            : AppColors.negative;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: color.withOpacity(0.12),
            color: color,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$score', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                Text('из 100', style: TextStyle(fontSize: 10, color: context.dim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final RadarRecommendation recommendation;
  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final reduce = recommendation.kind == RadarActionKind.reduce ||
        recommendation.kind == RadarActionKind.diversify;
    final color = reduce ? AppColors.gold : context.accent;
    return AppCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(color: color.withOpacity(0.28)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(11)),
            child: Icon(reduce ? Icons.balance_rounded : Icons.north_east_rounded, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recommendation.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(recommendation.explanation, style: TextStyle(fontSize: 11.8, height: 1.4, color: context.dim)),
              ],
            ),
          ),
          if (recommendation.amountRub != null) ...[
            const SizedBox(width: 8),
            Text(Fmt.compact(recommendation.amountRub!), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ],
        ],
      ),
    );
  }
}

class _DeviationRow extends StatelessWidget {
  final RadarDeviation deviation;
  const _DeviationRow({required this.deviation});

  @override
  Widget build(BuildContext context) {
    final color = deviation.deviationPct.abs() <= 2
        ? AppColors.positive
        : deviation.deviationPct > 0
            ? AppColors.gold
            : context.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(deviation.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              Text('${deviation.currentPct.toStringAsFixed(1)}% → ${deviation.targetPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11.5, color: context.dim)),
              const SizedBox(width: 8),
              TagChip(text: '${deviation.deviationPct >= 0 ? '+' : ''}${deviation.deviationPct.toStringAsFixed(1)} п.п.', color: color),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (deviation.currentPct / (deviation.targetPct <= 0 ? 100 : deviation.targetPct))
                  .clamp(0, 1)
                  .toDouble(),
              minHeight: 5,
              backgroundColor: color.withOpacity(0.10),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 10.8, color: context.dim)),
          ],
        ),
      );
}

class _TargetsEditor extends StatefulWidget {
  final VoidCallback onSaved;
  const _TargetsEditor({required this.onSaved});

  @override
  State<_TargetsEditor> createState() => _TargetsEditorState();
}

class _TargetsEditorState extends State<_TargetsEditor> {
  RadarTargetLevel level = RadarTargetLevel.sector;
  late Map<String, double> sectors;
  late Map<String, double> tickers;
  final keyController = TextEditingController();
  final valueController = TextEditingController();
  String? selectedSector;

  @override
  void initState() {
    super.initState();
    sectors = Map.of(RadarSettingsService.sectorTargets);
    tickers = Map.of(RadarSettingsService.tickerTargets);
  }

  @override
  void dispose() {
    keyController.dispose();
    valueController.dispose();
    super.dispose();
  }

  Map<String, double> get active => level == RadarTargetLevel.sector ? sectors : tickers;
  double get total => active.values.fold(0.0, (sum, value) => sum + value);

  void add() {
    final key = (level == RadarTargetLevel.sector ? (selectedSector ?? '') : keyController.text).trim();
    final value = double.tryParse(valueController.text.replaceAll(',', '.'));
    if (key.isEmpty || value == null || value <= 0) return;
    setState(() {
      active[level == RadarTargetLevel.ticker ? key.toUpperCase() : key] =
          value.clamp(0, 100).toDouble();
      keyController.clear();
      valueController.clear();
      selectedSector = null;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SheetHeader(
                  title: 'Цели распределения',
                  subtitle: 'Каждый уровень настраивается отдельно и должен давать 100%',
                  trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(height: 16),
                PillTabs<RadarTargetLevel>(
                  values: RadarTargetLevel.values,
                  selected: level,
                  labelOf: (v) => v == RadarTargetLevel.sector ? 'Секторы' : 'Бумаги',
                  onChanged: (v) => setState(() => level = v),
                ),
                const SizedBox(height: 14),
                if (level == RadarTargetLevel.sector)
                  DropdownButtonFormField<String>(
                    value: selectedSector,
                    decoration: const InputDecoration(labelText: 'Сектор'),
                    items: SectorService.allAvailableSectors
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) => setState(() => selectedSector = value),
                  )
                else
                  TextField(
                    controller: keyController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Тикер', hintText: 'Например, SBER'),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valueController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Целевая доля', suffixText: '%'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(onPressed: add, icon: const Icon(Icons.add_rounded)),
                  ],
                ),
                const SizedBox(height: 14),
                ...active.entries.map((entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${entry.value.toStringAsFixed(1)}%'),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => setState(() => active.remove(entry.key)),
                          ),
                        ],
                      ),
                    )),
                InfoBanner(
                  text: 'Сумма: ${total.toStringAsFixed(1)}%${(total - 100).abs() <= RadarSettingsService.targetTolerance ? ' — готово' : ' — нужно 100%'}',
                  icon: (total - 100).abs() <= RadarSettingsService.targetTolerance
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: (total - 100).abs() <= RadarSettingsService.targetTolerance
                      ? AppColors.positive
                      : AppColors.gold,
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Сохранить цели',
                  icon: Icons.save_outlined,
                  onPressed: () async {
                    await RadarSettingsService.save(sectorTargets: sectors, tickerTargets: tickers);
                    widget.onSaved();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
}

class _TradeSimulator extends StatefulWidget {
  final RadarSnapshot snapshot;
  const _TradeSimulator({required this.snapshot});

  @override
  State<_TradeSimulator> createState() => _TradeSimulatorState();
}

class _TradeSimulatorState extends State<_TradeSimulator> {
  RadarTradeKind kind = RadarTradeKind.buy;
  String? ticker;
  String sector = 'Без сектора';
  final qtyController = TextEditingController();
  final priceController = TextEditingController();
  final feeController = TextEditingController(text: '0');
  RadarSimulationResult? result;
  String? error;

  @override
  void dispose() {
    qtyController.dispose();
    priceController.dispose();
    feeController.dispose();
    super.dispose();
  }

  void selectTicker(String value) {
    final upper = value.toUpperCase();
    setState(() {
      ticker = upper;
      sector = SectorService.sectorFor(upper);
      final price = widget.snapshot.tickerPricesRub[upper];
      if (price != null) priceController.text = price.toStringAsFixed(2);
      result = null;
    });
  }

  void calculate() {
    final q = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 0;
    final p = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
    final fee = double.tryParse(feeController.text.replaceAll(',', '.')) ?? 0;
    try {
      final simulation = InvestRadarService.simulate(
        before: widget.snapshot,
        scenario: RadarTradeScenario(
          kind: kind,
          ticker: ticker ?? '',
          sector: sector,
          quantity: q,
          priceRub: p,
          feeRub: fee,
        ),
        sectorTargets: RadarSettingsService.sectorTargets,
        tickerTargets: RadarSettingsService.tickerTargets,
      );
      setState(() {
        result = simulation;
        error = null;
      });
    } catch (e) {
      setState(() {
        result = null;
        error = e is ArgumentError ? '${e.message}' : '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SheetHeader(
                  title: 'Симулятор сделки',
                  subtitle: 'Ничего не записывается в историю операций',
                  trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(height: 16),
                PillTabs<RadarTradeKind>(
                  values: RadarTradeKind.values,
                  selected: kind,
                  labelOf: (v) => v == RadarTradeKind.buy ? 'Покупка' : 'Продажа',
                  onChanged: (v) => setState(() {
                    kind = v;
                    result = null;
                  }),
                ),
                const SizedBox(height: 14),
                SecurityPickerField(onSelected: (s) => selectTicker(s.ticker)),
                if (kind == RadarTradeKind.sell && widget.snapshot.tickerValuesRub.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: ticker != null && widget.snapshot.tickerValuesRub.containsKey(ticker) ? ticker : null,
                    decoration: const InputDecoration(labelText: 'Или выбрать из портфеля'),
                    items: widget.snapshot.tickerValuesRub.keys
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) selectTicker(value);
                    },
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Количество',
                          helperText: kind == RadarTradeKind.sell && ticker != null
                              ? 'Доступно: ${Fmt.qty(widget.snapshot.tickerQuantities[ticker] ?? 0)}'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Цена', suffixText: '₽'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: feeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Комиссия', suffixText: '₽'),
                ),
                const SizedBox(height: 14),
                if (error != null) ...[
                  InfoBanner(text: error!, icon: Icons.error_outline_rounded, color: AppColors.negative),
                  const SizedBox(height: 10),
                ],
                if (result != null) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(child: _BeforeAfter(label: 'До', score: result!.before.healthScore)),
                        const Icon(Icons.arrow_forward_rounded),
                        Expanded(child: _BeforeAfter(label: 'После', score: result!.after.healthScore)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InfoBanner(
                    text: result!.healthDelta == 0
                        ? 'Оценка здоровья не изменится.'
                        : 'Изменение оценки: ${result!.healthDelta > 0 ? '+' : ''}${result!.healthDelta} пунктов.',
                    icon: result!.healthDelta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: result!.healthDelta >= 0 ? AppColors.positive : AppColors.negative,
                  ),
                  const SizedBox(height: 10),
                ],
                GradientButton(label: 'Рассчитать эффект', icon: Icons.auto_graph_rounded, onPressed: ticker == null ? null : calculate),
              ],
            ),
          ),
        ),
      );
}

class _BeforeAfter extends StatelessWidget {
  final String label;
  final int score;
  const _BeforeAfter({required this.label, required this.score});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: context.dim)),
          const SizedBox(height: 3),
          Text('$score / 100', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        ],
      );
}

class _AllocationSheet extends StatefulWidget {
  final RadarSnapshot snapshot;
  const _AllocationSheet({required this.snapshot});

  @override
  State<_AllocationSheet> createState() => _AllocationSheetState();
}

class _AllocationSheetState extends State<_AllocationSheet> {
  final amountController = TextEditingController();
  RadarAllocationPlan? plan;

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void calculate() {
    final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
    setState(() {
      plan = InvestRadarService.allocateNewMoney(
        snapshot: widget.snapshot,
        amountRub: amount,
        sectorTargets: RadarSettingsService.sectorTargets,
        tickerTargets: RadarSettingsService.tickerTargets,
      );
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SheetHeader(
                  title: 'Распределить новую сумму',
                  subtitle: 'Радар направит деньги в самые заметные недовесы',
                  trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Сумма пополнения', suffixText: '₽'),
                ),
                const SizedBox(height: 14),
                if (plan?.error != null) ...[
                  InfoBanner(text: plan!.error!, icon: Icons.info_outline_rounded, color: AppColors.gold),
                  const SizedBox(height: 10),
                ],
                if (plan?.isValid == true) ...[
                  ...plan!.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: [
                              Icon(Icons.north_east_rounded, color: context.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text(item.explanation, style: TextStyle(fontSize: 10.5, color: context.dim)),
                                  ],
                                ),
                              ),
                              Text(Fmt.money(item.amountRub), style: TextStyle(fontWeight: FontWeight.w900, color: context.accent)),
                            ],
                          ),
                        ),
                      )),
                  InfoBanner(
                    text: 'Это план, а не реальные сделки. Проверьте цены и лоты у брокера.',
                    icon: Icons.shield_outlined,
                    color: AppColors.info,
                  ),
                  const SizedBox(height: 10),
                ],
                GradientButton(label: 'Распределить', icon: Icons.call_split_rounded, onPressed: calculate),
              ],
            ),
          ),
        ),
      );
}
