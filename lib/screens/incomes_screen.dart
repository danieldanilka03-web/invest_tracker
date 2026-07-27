import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/income.dart';
import '../services/storage_service.dart';
import '../widgets/ticker_avatar.dart';
import '../widgets/security_picker_field.dart';

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({super.key});

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  IncomeType? _filterType;

  @override
  void initState() {
    super.initState();
    StorageService.dataVersion.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    StorageService.dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    var incomes = StorageService.incomes..sort((a, b) => b.date.compareTo(a.date));
    if (_filterType != null) {
      incomes = incomes.where((i) => i.type == _filterType).toList();
    }
    final total = incomes.fold<double>(0, (s, i) => s + i.amountNet);

    return Scaffold(
      appBar: AppBar(title: const Text('Дивиденды и купоны')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: total),
              builder: (context, value, _) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(colors: [const Color(0xFF0F3A34), Theme.of(context).colorScheme.secondary]),
                  boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.secondary.withOpacity(.24), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.savings_outlined, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('ПОЛУЧЕНО ПОСЛЕ НАЛОГА', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: .8, fontSize: 10)),
                      const SizedBox(height: 4),
                      Text('${value.toStringAsFixed(0)} ₽', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 27, letterSpacing: -.8)),
                    ])),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Все'),
                selected: _filterType == null,
                onSelected: (_) => setState(() => _filterType = null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Дивиденды'),
                selected: _filterType == IncomeType.dividend,
                onSelected: (_) => setState(() => _filterType = IncomeType.dividend),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Купоны'),
                selected: _filterType == IncomeType.coupon,
                onSelected: (_) => setState(() => _filterType = IncomeType.coupon),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: incomes.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.savings_outlined, size: 54, color: Theme.of(context).colorScheme.primary.withOpacity(.45)),
                    const SizedBox(height: 12),
                    const Text('Пока нет выплат', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Добавьте первую выплату по активу', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    itemCount: incomes.length,
                    itemBuilder: (context, i) {
                      final inc = incomes[i];
                      return Dismissible(
                        key: Key(inc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          StorageService.deleteIncome(inc.id);
                          setState(() {});
                        },
                        child: Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          child: ListTile(
                            leading: TickerAvatar(ticker: inc.ticker),
                            title: Text('${inc.ticker} — ${inc.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${_dateFormat.format(inc.date)} • '
                              '${inc.type == IncomeType.dividend ? "Дивиденд" : "Купон"} • '
                              'налог: ${inc.taxPaid.toStringAsFixed(2)} ${inc.currency}',
                            ),
                            trailing: Text(
                              '+${inc.amountNet.toStringAsFixed(2)} ${inc.currency}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
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
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Выплата'),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final tickerCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final taxCtrl = TextEditingController(text: '0');
    IncomeType type = IncomeType.dividend;
    String currency = 'RUB';
    DateTime date = DateTime.now();

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
              const Text('Новая выплата', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SegmentedButton<IncomeType>(
                segments: const [
                  ButtonSegment(value: IncomeType.dividend, label: Text('Дивиденд')),
                  ButtonSegment(value: IncomeType.coupon, label: Text('Купон')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setSheetState(() => type = s.first),
              ),
              const SizedBox(height: 12),
              SecurityPickerField(
                onSelected: (s) {
                  tickerCtrl.text = s.ticker;
                  nameCtrl.text = s.name;
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Сумма до налога', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: taxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Налог удержан', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: currency,
                      decoration: const InputDecoration(labelText: 'Валюта', border: OutlineInputBorder()),
                      items: ['RUB', 'USD', 'EUR', 'CNY']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setSheetState(() => currency = v ?? 'RUB'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2015),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setSheetState(() => date = picked);
                      },
                      child: Text(DateFormat('dd.MM.yyyy').format(date)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                  final tax = double.tryParse(taxCtrl.text.replaceAll(',', '.')) ?? 0;
                  if (tickerCtrl.text.isEmpty || amount == null) return;
                  StorageService.addIncome(Income(
                    id: const Uuid().v4(),
                    date: date,
                    ticker: tickerCtrl.text.toUpperCase(),
                    name: nameCtrl.text.isEmpty ? tickerCtrl.text : nameCtrl.text,
                    type: type,
                    amountGross: amount,
                    taxPaid: tax,
                    currency: currency,
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
