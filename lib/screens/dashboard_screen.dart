import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/favorites_service.dart';
import '../services/cash_service.dart';
import '../services/tax_service.dart';
import '../widgets/ticker_avatar.dart';
import 'ticker_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PeriodFilter _period = PeriodFilter.all;
  PeriodFilter _incomeChartPeriod = PeriodFilter.year1;

  String _periodLabel(PeriodFilter f) {
    switch (f) {
      case PeriodFilter.month1:
        return '1 мес';
      case PeriodFilter.month3:
        return '3 мес';
      case PeriodFilter.month6:
        return '6 мес';
      case PeriodFilter.year1:
        return '1 год';
      case PeriodFilter.all:
        return 'Всё время';
    }
  }

  final _sectorColors = const [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFE84393),
    Color(0xFFFDCB6E),
    Color(0xFF00CEC9),
    Color(0xFFD63031),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: StorageService.dataVersion,
      builder: (context, _, __) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final timeline = AnalyticsService.portfolioValueTimeline();
    final currentValue = AnalyticsService.currentPortfolioValueRub();
    final unrealizedPnl = AnalyticsService.totalUnrealizedPnlRub();
    final holdings = AnalyticsService.currentHoldings();
    final invested = AnalyticsService.totalInvested(f: _period);
    final income = AnalyticsService.totalIncome(f: _period);
    final bySector = AnalyticsService.investedBySector(f: _period);
    final incomeByMonth = AnalyticsService.incomeByMonth(f: _incomeChartPeriod);
    final cashBalance = CashService.balance;
    final concentration = AnalyticsService.topHoldingConcentrationPct();
    final topTicker = AnalyticsService.topHoldingTicker();
    final xirr = AnalyticsService.xirrPercent();
    final taxDue = TaxService.enabled ? TaxService.totalTaxDue() : 0.0;
    final primary = Theme.of(context).colorScheme.primary;

    // прирост стоимости за отображаемый период (по timeline)
    double? changeAbs;
    double? changePct;
    if (timeline.length > 1) {
      final first = timeline.first.value;
      final last = timeline.last.value;
      if (first > 0) {
        changeAbs = last - first;
        changePct = (changeAbs / first) * 100;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой портфель'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // --- Hero-карточка стоимости портфеля ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, primary.withOpacity(0.75)],
              ),
              boxShadow: [
                BoxShadow(color: primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Стоимость портфеля', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  (currentValue + cashBalance).toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: GestureDetector(
                    onTap: () => _showEditCashDialog(context, cashBalance),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'бумаги: ${currentValue.toStringAsFixed(0)} • свободные: ${cashBalance.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, color: Colors.white70, size: 12),
                      ],
                    ),
                  ),
                ),
                if (changeAbs != null && changePct != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          changeAbs >= 0 ? Icons.trending_up : Icons.trending_down,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${changeAbs >= 0 ? "+" : ""}${changeAbs.toStringAsFixed(0)} (${changePct.toStringAsFixed(1)}%)',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(' за ${_periodLabel(_period).toLowerCase()}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                if (holdings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          unrealizedPnl >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'P&L по открытым позициям: ${unrealizedPnl >= 0 ? "+" : ""}${unrealizedPnl.toStringAsFixed(0)} ₽',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (timeline.length > 1)
                  SizedBox(
                    height: 120,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [for (int i = 0; i < timeline.length; i++) FlSpot(i.toDouble(), timeline[i].value)],
                            isCurved: true,
                            color: Colors.white,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: Colors.white.withOpacity(0.15)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Добавь первую покупку, чтобы увидеть график', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- фильтр периода ---
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: PeriodFilter.values
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_periodLabel(f)),
                          selected: _period == f,
                          onSelected: (_) => setState(() => _period = f),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _miniStat(context, 'Вложено', invested, Icons.account_balance_wallet_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _miniStat(context, 'Доход', income, Icons.payments_outlined)),
            ],
          ),
          if (xirr != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.percent, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Доходность (XIRR)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        Text(
                          '${xirr >= 0 ? "+" : ""}${xirr.toStringAsFixed(1)}% годовых',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: xirr >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (taxDue > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 20, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Налог с продаж (НДФЛ)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        Text(
                          '~${taxDue.toStringAsFixed(0)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (concentration > 40 && topTicker != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$topTicker занимает ${concentration.toStringAsFixed(0)}% портфеля — низкая диверсификация',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // --- Избранное ---
          ValueListenableBuilder<int>(
            valueListenable: FavoritesService.version,
            builder: (context, _, __) {
              final favs = FavoritesService.all;
              if (favs.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Избранное', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 84,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: favs.length,
                      itemBuilder: (context, i) {
                        final t = favs[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TickerDetailScreen(ticker: t)),
                            ),
                            child: Column(
                              children: [
                                TickerAvatar(ticker: t, size: 48),
                                const SizedBox(height: 6),
                                Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

          // --- Состав портфеля ---
          if (holdings.isNotEmpty) ...[
            const Text('Состав портфеля', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ...holdings.entries.map((e) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: ListTile(
                    leading: TickerAvatar(ticker: e.key, size: 36),
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${e.value.qty.toStringAsFixed(e.value.qty == e.value.qty.roundToDouble() ? 0 : 2)} шт • ср. ${e.value.avgCost.toStringAsFixed(2)} → ${e.value.lastPrice.toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              e.value.valueRub.toStringAsFixed(0),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                            Text(
                              '${e.value.pnlRub >= 0 ? "+" : ""}${e.value.pnlPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: e.value.pnlRub >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: FavoritesService.version,
                          builder: (context, _, __) {
                            final isFav = FavoritesService.isFavorite(e.key);
                            return IconButton(
                              icon: Icon(isFav ? Icons.star : Icons.star_border,
                                  size: 20, color: isFav ? Colors.amber : Colors.grey),
                              onPressed: () => FavoritesService.toggle(e.key),
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TickerDetailScreen(ticker: e.key)),
                    ),
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // --- Пирог по секторам ---
          if (bySector.isNotEmpty) ...[
            const Text('Распределение по секторам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final total = bySector.values.fold(0.0, (s, v) => s + v);
              return Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: PieChart(
                      PieChartData(
                        sections: [
                          for (int i = 0; i < bySector.length; i++)
                            PieChartSectionData(
                              value: bySector.values.elementAt(i),
                              color: _sectorColors[i % _sectorColors.length],
                              title: '',
                              radius: 50,
                            ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int i = 0; i < bySector.length; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _sectorColors[i % _sectorColors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${bySector.keys.elementAt(i)} ${total > 0 ? (bySector.values.elementAt(i) / total * 100).toStringAsFixed(0) : 0}%',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),
          ],

          // --- Доход по месяцам ---
          if (StorageService.incomes.isNotEmpty) ...[
            const Text('Дивиденды и купоны по месяцам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('6 мес'),
                  selected: _incomeChartPeriod == PeriodFilter.month6,
                  onSelected: (_) => setState(() => _incomeChartPeriod = PeriodFilter.month6),
                ),
                ChoiceChip(
                  label: const Text('1 год'),
                  selected: _incomeChartPeriod == PeriodFilter.year1,
                  onSelected: (_) => setState(() => _incomeChartPeriod = PeriodFilter.year1),
                ),
                ChoiceChip(
                  label: const Text('Всё время'),
                  selected: _incomeChartPeriod == PeriodFilter.all,
                  onSelected: (_) => setState(() => _incomeChartPeriod = PeriodFilter.all),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (incomeByMonth.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Нет выплат за выбранный период', style: TextStyle(color: Colors.grey.shade500)),
                ),
              )
            else
              _buildIncomeLineChart(context, incomeByMonth),
          ],

          if (holdings.isEmpty && income == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.insights_outlined, size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Добавь первую покупку,\nчтобы увидеть статистику',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _monthNames = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = parts[0].substring(2);
    final month = int.parse(parts[1]);
    return '${_monthNames[month - 1]} $year';
  }

  Widget _buildIncomeLineChart(BuildContext context, Map<String, double> data) {
    final keys = data.keys.toList();
    final values = data.values.toList();
    final primary = Theme.of(context).colorScheme.primary;
    const pointWidth = 64.0;
    final needsScroll = keys.length > 6;
    final chartWidth = needsScroll ? keys.length * pointWidth : null;

    Widget chart = SizedBox(
      height: 200,
      width: chartWidth,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_monthLabel(keys[idx]), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                return LineTooltipItem(
                  '${_monthLabel(keys[s.x.toInt()])}\n${values[s.x.toInt()].toStringAsFixed(0)} ₽',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
              isCurved: true,
              curveSmoothness: 0.3,
              color: primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(show: true, color: primary.withOpacity(0.15)),
            ),
          ],
        ),
      ),
    );

    if (needsScroll) {
      chart = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // сразу открывается на последних (самых свежих) месяцах
        child: chart,
      );
    }
    return chart;
  }

  Future<void> _showEditCashDialog(BuildContext context, double current) async {
    final ctrl = TextEditingController(text: current == 0 ? '' : current.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Свободные средства'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Деньги на счету, которые ещё не вложены в бумаги (например, только что внесённые, или вырученные от продажи).',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Сумма, ₽', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
              await CashService.setBalance(value);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String label, double value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text(value.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
