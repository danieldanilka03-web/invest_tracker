import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/plan.dart';
import '../models/purchase.dart';
import '../services/storage_service.dart';
import '../widgets/ticker_avatar.dart';
import '../widgets/security_picker_field.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');

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

  Color _statusColor(PlanStatus s, BuildContext context) {
    switch (s) {
      case PlanStatus.active:
        return Theme.of(context).colorScheme.primary;
      case PlanStatus.done:
        return Colors.green;
      case PlanStatus.cancelled:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = StorageService.plans
      ..sort((a, b) {
        if (a.status != b.status) {
          return a.status == PlanStatus.active ? -1 : 1;
        }
        return (a.targetDate ?? DateTime(2100)).compareTo(b.targetDate ?? DateTime(2100));
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Планы покупок')),
      body: plans.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Пока нет запланированных покупок', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: plans.length,
              itemBuilder: (context, i) {
                final p = plans[i];
                final isDone = p.status == PlanStatus.done;
                final isCancelled = p.status == PlanStatus.cancelled;

                return Dismissible(
                  key: Key(p.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(context),
                  background: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    StorageService.deletePlan(p.id);
                    setState(() {});
                  },
                  child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Opacity(
                            opacity: isCancelled ? 0.4 : 1,
                            child: TickerAvatar(ticker: p.ticker, size: 36),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${p.ticker} — ${p.name}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: isDone || isCancelled ? TextDecoration.lineThrough : null,
                                color: isCancelled ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Text(
                              '${_typeLabel(p.type)} • цель: ${p.targetQuantity} шт'
                              '${p.targetPrice != null ? " по ${p.targetPrice}" : ""}'
                              '${p.estimatedTotal != null ? " (≈${p.estimatedTotal!.toStringAsFixed(0)})" : ""}\n'
                              '${p.targetDate != null ? "к ${_dateFormat.format(p.targetDate!)}" : "без срока"}'
                              '${p.note?.isNotEmpty == true ? " • ${p.note}" : ""}',
                            ),
                            isThreeLine: true,
                          ),
                        ),
                        Column(
                          children: [
                            Checkbox(
                              value: isDone,
                              onChanged: (v) {
                                p.status = v == true ? PlanStatus.done : PlanStatus.active;
                                StorageService.updatePlan(p);
                                setState(() {});
                              },
                            ),
                            PopupMenuButton<PlanStatus>(
                              icon: Icon(Icons.flag, size: 18, color: _statusColor(p.status, context)),
                              onSelected: (s) {
                                p.status = s;
                                StorageService.updatePlan(p);
                                setState(() {});
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: PlanStatus.active, child: Text('Активный')),
                                PopupMenuItem(value: PlanStatus.done, child: Text('Выполнен')),
                                PopupMenuItem(value: PlanStatus.cancelled, child: Text('Отменён')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить план?'),
            content: const Text('Запланированная покупка будет удалена без возможности восстановления.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
            ],
          ),
        ) ??
        false;
  }

  void _showAddDialog(BuildContext context) {
    final tickerCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    AssetType type = AssetType.stock;
    DateTime? targetDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Новый план', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SecurityPickerField(
                onSelected: (s) {
                  tickerCtrl.text = s.ticker;
                  nameCtrl.text = s.name;
                  setSheetState(() {
                    type = s.type;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tickerCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Тикер', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AssetType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Тип актива', border: OutlineInputBorder()),
                items: AssetType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
                    .toList(),
                onChanged: (v) => setSheetState(() => type = v ?? AssetType.stock),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Кол-во (цель)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Желаемая цена', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: targetDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setSheetState(() => targetDate = picked);
                },
                child: Text(targetDate == null
                    ? 'Срок (необязательно)'
                    : 'Срок: ${DateFormat('dd.MM.yyyy').format(targetDate!)}'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Заметка (необязательно)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.'));
                  final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                  if (tickerCtrl.text.isEmpty || qty == null) return;
                  StorageService.addPlan(Plan(
                    id: const Uuid().v4(),
                    ticker: tickerCtrl.text.toUpperCase(),
                    name: nameCtrl.text.isEmpty ? tickerCtrl.text : nameCtrl.text,
                    type: type,
                    targetQuantity: qty,
                    targetPrice: price,
                    targetDate: targetDate,
                    note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                    createdAt: DateTime.now(),
                  ));
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Добавить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
