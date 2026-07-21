import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../widgets/ticker_avatar.dart';

class TickerDetailScreen extends StatelessWidget {
  final String ticker;
  const TickerDetailScreen({super.key, required this.ticker});

  @override
  Widget build(BuildContext context) {
    final history = AnalyticsService.priceHistoryForTicker(ticker);
    final purchases = StorageService.purchases.where((p) => p.ticker == ticker).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final holdings = AnalyticsService.currentHoldings()[ticker];
    final dateFormat = DateFormat('dd.MM.yyyy');
    final name = purchases.isNotEmpty ? purchases.first.name : ticker;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            TickerAvatar(ticker: ticker, size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text(ticker, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(name, style: const TextStyle(fontSize: 15, color: Colors.grey)),
          const SizedBox(height: 16),
          if (holdings != null)
            Row(
              children: [
                Expanded(
                  child: _statCard(context, 'В портфеле', '${holdings.qty.toStringAsFixed(holdings.qty == holdings.qty.roundToDouble() ? 0 : 2)} шт'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(context, 'Последняя цена', holdings.lastPrice.toStringAsFixed(2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(context, 'Стоимость', holdings.value.toStringAsFixed(0)),
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (history.length > 1) ...[
            const Text('История цены покупки', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      spots: [
                        for (int i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i].value),
                      ],
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
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
                  title: Text('${p.quantity.toStringAsFixed(p.quantity == p.quantity.roundToDouble() ? 0 : 2)} шт × ${p.pricePerUnit}'),
                  subtitle: Text(dateFormat.format(p.date)),
                  trailing: Text('${p.total.toStringAsFixed(0)} ${p.currency}'),
                ),
              )),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value) {
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
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
