import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/purchase.dart';
import '../models/plan.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/tax_service.dart';
import '../widgets/ticker_avatar.dart';
import '../widgets/security_picker_field.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  AssetType? _filterType;
  bool? _filterIsSell; // null = все, false = только покупки, true = только продажи

  String _typeLabel(AssetType t) {
    switch (t) {
      case AssetType.stock:
        return 'Акция';
      case AssetType.bond:
        return 'Облигация';
      case AssetType.etf:
        return 'Фонд';
      case AssetType.currency:
        return 'Валюта';
      case AssetType.other:
        return 'Другое';
    }
  }

  @override
  Widget build(BuildContext context) {
    var purchases = StorageService.purchases..sort((a, b) => b.date.compareTo(a.date));
    if (_filterType != null) {
      purchases = purchases.where((p) => p.type == _filterType).toList();
    }
    if (_filterIsSell != null) {
      purchases = purchases.where((p) => p.isSell == _filterIsSell).toList();
    }
    final taxBreakdown = TaxService.enabled ? TaxService.saleTaxBreakdown() : <String, SaleTaxResult>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Покупки')),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _opChip(null, 'Все операции'),
                _opChip(false, 'Покупки'),
                _opChip(true, 'Продажи'),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip(null, 'Все'),
                ...AssetType.values.map((t) => _filterChip(t, _typeLabel(t))),
              ],
            ),
          ),
          Expanded(
            child: purchases.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: purchases.length,
                    itemBuilder: (context, i) {
                      final p = purchases[i];
                      return Dismissible(
                        key: Key(p.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmDelete(context),
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          StorageService.deletePurchase(p.id);
                          setState(() {});
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            leading: TickerAvatar(ticker: p.ticker),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text('${p.ticker} · ${p.name}',
                                      style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                ),
                                if (p.isSell)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Продажа', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${_dateFormat.format(p.date)} • ${p.quantity.toStringAsFixed(p.quantity == p.quantity.roundToDouble() ? 0 : 2)} шт × ${p.pricePerUnit}\n'
                              '${_typeLabel(p.type)}${p.sector != null ? ' • ${p.sector}' : ''}'
                              '${p.isSell && taxBreakdown[p.id] != null ? _taxSubtitle(taxBreakdown[p.id]!) : ''}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              '${p.isSell ? "+" : "-"}${p.total.toStringAsFixed(0)} ${p.currency}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: p.isSell ? Colors.red : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTradeSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Сделка'),
      ),
    );
  }

  Future<void> _checkPlansForTickers(BuildContext context, Set<String> tickers) async {
    if (tickers.isEmpty) return;
    final matchingPlans = StorageService.plans
        .where((p) => p.status == PlanStatus.active && tickers.contains(p.ticker.toUpperCase()))
        .toList();
    for (final plan in matchingPlans) {
      if (!context.mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Есть активный план'),
          content: Text('У тебя есть план на покупку ${plan.ticker} — отметить его выполненным?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Не сейчас')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отметить выполненным')),
          ],
        ),
      );
      if (confirm == true) {
        plan.status = PlanStatus.done;
        await StorageService.updatePlan(plan);
      }
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить покупку?'),
            content: const Text('Запись будет удалена без возможности восстановления.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
            ],
          ),
        ) ??
        false;
  }

  String _taxSubtitle(SaleTaxResult r) {
    if (r.realizedGainRub <= 0) return ' • без налога (убыток)';
    if (r.taxableGainRub <= 0 && r.hasLdvPortion) return ' • без налога (ЛДВ)';
    if (r.taxRub > 0) return ' • налог: ~${r.taxRub.toStringAsFixed(0)} ₽';
    return '';
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Пока нет покупок', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text('Нажми "Сделка", чтобы добавить одну или несколько бумаг', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _opChip(bool? isSell, String label) {
    final selected = _filterIsSell == isSell;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterIsSell = isSell),
      ),
    );
  }

  Widget _filterChip(AssetType? type, String label) {
    final selected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterType = type),
      ),
    );
  }

  void _showAddTradeSheet(BuildContext context) {
    DateTime date = DateTime.now();
    final positions = <_PositionDraft>[_PositionDraft()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
          final maxSheetHeight = MediaQuery.of(ctx).size.height - keyboardHeight - 60;
          return Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight > 200 ? maxSheetHeight : 200),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Новая сделка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2015),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setSheetState(() => date = picked);
                        },
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(DateFormat('dd.MM.yyyy').format(date)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Можно добавить сразу несколько бумаг одной сделкой',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: positions.length,
                      itemBuilder: (context, i) => _PositionCard(
                        draft: positions[i],
                        index: i,
                        onRemove: positions.length > 1
                            ? () => setSheetState(() => positions.removeAt(i))
                            : null,
                        onChanged: () => setSheetState(() {}),
                      ),
                    ),
                  ),
                  if (keyboardHeight == 0) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setSheetState(() => positions.add(_PositionDraft())),
                      icon: const Icon(Icons.add),
                      label: const Text('Ещё одна бумага'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        int added = 0;
                        final addedTickers = <String>{};
                        for (final pos in positions) {
                          final qty = double.tryParse(pos.qtyCtrl.text.replaceAll(',', '.'));
                          final price = double.tryParse(pos.priceCtrl.text.replaceAll(',', '.'));
                          if (pos.tickerCtrl.text.isEmpty || qty == null || price == null) continue;
                          final fee = double.tryParse(pos.feeCtrl.text.replaceAll(',', '.')) ?? 0;
                          final ticker = pos.tickerCtrl.text.toUpperCase();
                          StorageService.addPurchase(Purchase(
                            id: const Uuid().v4(),
                            date: date,
                            ticker: ticker,
                            name: pos.nameCtrl.text.isEmpty ? pos.tickerCtrl.text : pos.nameCtrl.text,
                            type: pos.type,
                            quantity: qty,
                            pricePerUnit: price,
                            fee: fee,
                            currency: pos.currency,
                            sector: pos.sector,
                            isSell: pos.isSell,
                          ));
                          added++;
                          if (!pos.isSell) addedTickers.add(ticker);
                        }
                        if (added > 0) {
                          Navigator.pop(ctx);
                          setState(() {});
                          // Проверяем, нет ли активных планов на купленные тикеры —
                          // предлагаем сразу отметить их выполненными
                          if (context.mounted) {
                            await _checkPlansForTickers(context, addedTickers);
                          }
                        }
                      },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('Сохранить (${positions.length} ${positions.length == 1 ? "позиция" : "позиции"})'),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }
}

/// Черновик одной позиции внутри мультипозиционной сделки
class _PositionDraft {
  final tickerCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final feeCtrl = TextEditingController(text: '0');
  AssetType type = AssetType.stock;
  String currency = 'RUB';
  String? sector;
  bool isSell = false;
}

class _PositionCard extends StatelessWidget {
  final _PositionDraft draft;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _PositionCard({
    required this.draft,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  String _typeLabel(AssetType t) {
    switch (t) {
      case AssetType.stock:
        return 'Акция';
      case AssetType.bond:
        return 'Облигация';
      case AssetType.etf:
        return 'Фонд';
      case AssetType.currency:
        return 'Валюта';
      case AssetType.other:
        return 'Другое';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Бумага ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            SecurityPickerField(
              onSelected: (s) {
                draft.tickerCtrl.text = s.ticker;
                draft.nameCtrl.text = s.name;
                draft.type = s.type;
                draft.sector = s.sector;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Покупка'), icon: Icon(Icons.add_shopping_cart, size: 16)),
                ButtonSegment(value: true, label: Text('Продажа'), icon: Icon(Icons.sell_outlined, size: 16)),
              ],
              selected: {draft.isSell},
              onSelectionChanged: (s) {
                draft.isSell = s.first;
                onChanged();
              },
            ),
            if (draft.isSell && draft.tickerCtrl.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Builder(
                  builder: (context) {
                    final holding = AnalyticsService.currentHoldings()[draft.tickerCtrl.text.toUpperCase()];
                    final qty = holding?.qty ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: qty > 0
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        qty > 0
                            ? 'На счету: ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} шт'
                            : 'Этой бумаги нет на счету',
                        style: TextStyle(
                          fontSize: 12,
                          color: qty > 0 ? null : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.tickerCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Тикер', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: draft.nameCtrl,
                    decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<AssetType>(
              value: draft.type,
              decoration: const InputDecoration(labelText: 'Тип актива', border: OutlineInputBorder(), isDense: true),
              items: AssetType.values.map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t)))).toList(),
              onChanged: (v) {
                draft.type = v ?? AssetType.stock;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Кол-во', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: draft.priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Цена', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.feeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Комиссия', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: draft.currency,
                    decoration: const InputDecoration(labelText: 'Валюта', border: OutlineInputBorder(), isDense: true),
                    items: ['RUB', 'USD', 'EUR', 'CNY'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      draft.currency = v ?? 'RUB';
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
