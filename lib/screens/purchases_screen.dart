import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/purchase.dart';
import '../services/storage_service.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Покупки')),
      body: Column(
        children: [
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
                            title: Text('${p.ticker} · ${p.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${_dateFormat.format(p.date)} • ${p.quantity.toStringAsFixed(p.quantity == p.quantity.roundToDouble() ? 0 : 2)} шт × ${p.pricePerUnit}\n'
                              '${_typeLabel(p.type)}${p.sector != null ? ' • ${p.sector}' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              '${p.total.toStringAsFixed(0)} ${p.currency}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
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
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
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
                      controller: scrollController,
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => setSheetState(() => positions.add(_PositionDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Ещё одна бумага'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      int added = 0;
                      for (final pos in positions) {
                        final qty = double.tryParse(pos.qtyCtrl.text.replaceAll(',', '.'));
                        final price = double.tryParse(pos.priceCtrl.text.replaceAll(',', '.'));
                        if (pos.tickerCtrl.text.isEmpty || qty == null || price == null) continue;
                        final fee = double.tryParse(pos.feeCtrl.text.replaceAll(',', '.')) ?? 0;
                        StorageService.addPurchase(Purchase(
                          id: const Uuid().v4(),
                          date: date,
                          ticker: pos.tickerCtrl.text.toUpperCase(),
                          name: pos.nameCtrl.text.isEmpty ? pos.tickerCtrl.text : pos.nameCtrl.text,
                          type: pos.type,
                          quantity: qty,
                          pricePerUnit: price,
                          fee: fee,
                          currency: pos.currency,
                          sector: pos.sector,
                        ));
                        added++;
                      }
                      if (added > 0) {
                        Navigator.pop(ctx);
                        setState(() {});
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text('Сохранить (${positions.length} ${positions.length == 1 ? "позиция" : "позиции"})'),
                    ),
                  ),
                ],
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.tickerCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Тикер', border: OutlineInputBorder(), isDense: true),
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
