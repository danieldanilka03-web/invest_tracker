import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/favorites_service.dart';
import '../widgets/ticker_avatar.dart';

class TickerDetailScreen extends StatefulWidget {
  final String ticker;
  const TickerDetailScreen({super.key, required this.ticker});

  @override
  State<TickerDetailScreen> createState() => _TickerDetailScreenState();
}

class _TickerDetailScreenState extends State<TickerDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final ticker = widget.ticker;
    final history = AnalyticsService.priceHistoryForTicker(ticker);
    final purchases = StorageService.purchases.where((p) => p.ticker == ticker).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final holding = AnalyticsService.currentHoldings()[ticker];
    final dateFormat = DateFormat('dd.MM.yyyy');
    final name = purchases.isNotEmpty ? purchases.first.name : ticker;
    final isFav = FavoritesService.isFavorite(ticker);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            TickerAvatar(ticker: ticker, size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text(ticker, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : null),
            onPressed: () async {
              await FavoritesService.toggle(ticker);
              setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(name, style: const TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 16),
          if (holding != null) ...[
            Row(
              children: [
                Expanded(
                  child: _statCard(context, 'В портфеле',
                      '${holding.qty.toStringAsFixed(holding.qty == holding.qty.roundToDouble() ? 0 : 2)} шт'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(context, 'Средняя цена', holding.avgCost.toStringAsFixed(2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(context, 'Последняя цена', holding.lastPrice.toStringAsFixed(2)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statCard(context, 'Стоимость', holding.valueRub.toStringAsFixed(0)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    context,
                    'Прибыль/убыток',
                    '${holding.pnlRub >= 0 ? "+" : ""}${holding.pnlRub.toStringAsFixed(0)} (${holding.pnlPct.toStringAsFixed(1)}%)',
                    valueColor: holding.pnlRub >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Эта бумага сейчас не в портфеле (продана полностью)', style: TextStyle(color: Colors.grey.shade500)),
            ),
          const SizedBox(height: 24),
          if (history.length > 1) ...[
            const Text('История сделок по цене', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (int i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i].price)],
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 4,
                          color: history[index].isSell ? Colors.red : Theme.of(context).colorScheme.primary,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(width: 4),
                  const Text('Покупка', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 12),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red)),
                  const SizedBox(width: 4),
                  const Text('Продажа', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          const Text('Сделки по этой бумаге', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...purchases.map((p) => Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    p.isSell ? Icons.arrow_upward : Icons.arrow_downward,
                    color: p.isSell ? Colors.red : Colors.green,
                  ),
                  title: Text(
                      '${p.isSell ? "Продажа" : "Покупка"} • ${p.quantity.toStringAsFixed(p.quantity == p.quantity.roundToDouble() ? 0 : 2)} шт × ${p.pricePerUnit}'),
                  subtitle: Text(dateFormat.format(p.date)),
                  trailing: Text(
                    '${p.isSell ? "+" : "-"}${p.total.toStringAsFixed(0)} ${p.currency}',
                    style: TextStyle(color: p.isSell ? Colors.red : null, fontWeight: FontWeight.w600),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value, {Color? valueColor}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor)),
          ],
        ),
      ),
    );
  }
}
