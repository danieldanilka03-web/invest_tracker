import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/favorites_service.dart';
import '../services/tax_service.dart';
import '../services/manual_price_service.dart';
import '../services/logo_service.dart';
import '../models/income.dart';
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
    final incomes = StorageService.incomes.where((i) => i.ticker == ticker).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final incomeTotal = incomes.fold<double>(0, (s, i) => s + i.amountNet);
    final openLots = (AnalyticsService.currentHoldings().containsKey(ticker) && TaxService.enabled)
        ? TaxService.openLotsForTicker(ticker)
        : <OpenLotInfo>[];
    final taxBreakdown = TaxService.enabled ? TaxService.saleTaxBreakdown() : <String, SaleTaxResult>{};
    final dateFormat = DateFormat('dd.MM.yyyy');
    final name = purchases.isNotEmpty ? purchases.first.name : ticker;
    final isFav = FavoritesService.isFavorite(ticker);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: () => _pickLogo(context, ticker),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  TickerAvatar(ticker: ticker, size: 32),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt, size: 10, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
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
                  child: GestureDetector(
                    onTap: () => _showSetPriceDialog(context, ticker, holding),
                    child: _statCard(
                      context,
                      holding.hasManualPrice ? 'Текущая цена ✎' : 'Последняя цена ✎',
                      holding.displayPrice.toStringAsFixed(2),
                      valueColor: holding.hasManualPrice ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
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
          if (openLots.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildLdvCard(context, openLots),
          ],
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
          if (incomes.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Дивиденды и купоны', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '+${incomeTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...incomes.map((i) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      i.type == IncomeType.dividend ? Icons.trending_up : Icons.receipt_long,
                      color: Colors.green,
                    ),
                    title: Text(i.type == IncomeType.dividend ? 'Дивиденд' : 'Купон'),
                    subtitle: Text(dateFormat.format(i.date)),
                    trailing: Text(
                      '+${i.amountNet.toStringAsFixed(2)} ${i.currency}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
                )),
            const SizedBox(height: 24),
          ],
          const Text('Сделки по этой бумаге', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...purchases.map((p) {
            final tax = p.isSell ? taxBreakdown[p.id] : null;
            return Card(
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
                subtitle: Text(
                  tax != null ? '${dateFormat.format(p.date)}${_taxLine(tax)}' : dateFormat.format(p.date),
                ),
                isThreeLine: tax != null && tax.realizedGainRub > 0,
                trailing: Text(
                  '${p.isSell ? "+" : "-"}${p.total.toStringAsFixed(0)} ${p.currency}',
                  style: TextStyle(color: p.isSell ? Colors.red : null, fontWeight: FontWeight.w600),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickLogo(BuildContext context, String ticker) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;
    await LogoService.setLogo(ticker, File(picked.path));
    setState(() {});
  }

  Future<void> _showSetPriceDialog(BuildContext context, String ticker, HoldingInfo holding) async {
    final ctrl = TextEditingController(
      text: holding.hasManualPrice ? holding.displayPrice.toStringAsFixed(2) : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Текущая цена'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Приложение офлайн и не тянет котировки, поэтому по умолчанию используется цена последней сделки. '
              'Укажи актуальную цену вручную, чтобы стоимость портфеля и графики пересчитались честно.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Цена, ${holding.currency}', border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          if (holding.hasManualPrice)
            TextButton(
              onPressed: () async {
                await ManualPriceService.clear(ticker);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('Сбросить'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final price = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (price == null || price <= 0) return;
              await ManualPriceService.set(ticker, price);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  String _taxLine(SaleTaxResult tax) {
    if (tax.realizedGainRub <= 0) return '\nБез налога (убыток)';
    if (tax.taxableGainRub <= 0 && tax.hasLdvPortion) return '\nБез налога (ЛДВ)';
    if (tax.taxRub > 0) return '\nНалог: ~${tax.taxRub.toStringAsFixed(0)} ₽';
    return '';
  }

  Widget _buildLdvCard(BuildContext context, List<OpenLotInfo> lots) {
    final waiting = lots.where((l) => !l.ldvActive).toList();
    if (waiting.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Льгота на долгосрочное владение (ЛДВ) уже действует на всю позицию — прибыль с продажи не облагается налогом',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            ),
          ],
        ),
      );
    }
    waiting.sort((a, b) => a.daysUntilLdv.compareTo(b.daysUntilLdv));
    final nearest = waiting.first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'До льготы ЛДВ по части позиции (${nearest.qty.toStringAsFixed(nearest.qty == nearest.qty.roundToDouble() ? 0 : 2)} шт) осталось ${nearest.daysUntilLdv} дн.',
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
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
