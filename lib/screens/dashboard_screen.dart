import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';
import '../services/favorites_service.dart';
import '../widgets/ticker_avatar.dart';
import 'ticker_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PeriodFilter _period = PeriodFilter.all;

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
    final timeline = AnalyticsService.portfolioValueTimeline();
    final currentValue = AnalyticsService.currentPortfolioValue();
    final holdings = AnalyticsService.currentHoldings();
    final invested = AnalyticsService.totalInvested(f: _period);
    final income = AnalyticsService.totalIncome(f: _period);
    final bySector = AnalyticsService.investedBySector(f: _period);
    final incomeByMonth = AnalyticsService.incomeByMonth(f: _period == PeriodFilter.all ? PeriodFilter.year1 : _period);
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
                  currentValue.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
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
                    subtitle: Text('${e.value.qty.toStringAsFixed(e.value.qty == e.value.qty.roundToDouble() ? 0 : 2)} шт • по ${e.value.lastPrice}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.value.value.toStringAsFixed(0),
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
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
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: [
                          for (int i = 0; i < bySector.length; i++)
                            PieChartSectionData(
                              value: bySector.values.elementAt(i),
                              color: _sectorColors[i % _sectorColors.length],
                              title: '',
                              radius: 55,
                            ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 38,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < bySector.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _sectorColors[i % _sectorColors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${bySector.keys.elementAt(i)}: ${bySector.values.elementAt(i).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // --- Доход по месяцам ---
          if (incomeByMonth.isNotEmpty) ...[
            const Text('Дивиденды и купоны по месяцам', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final keys = incomeByMonth.keys.toList();
                          final idx = value.toInt();
                          if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                          final parts = keys[idx].split('-');
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(parts[1], style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < incomeByMonth.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: incomeByMonth.values.elementAt(i),
                            color: Colors.green,
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
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
