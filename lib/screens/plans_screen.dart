import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/plan.dart';
import '../models/purchase.dart';
import '../services/storage_service.dart';
import '../widgets/ticker_avatar.dart';
import '../widgets/security_picker_field.dart';

enum _DatePreset { all, thisMonth, next3Months, overdue, custom }

/// Сумма планов по одному тикеру за выбранный период (для сводной карточки
/// сверху экрана) — объединяет планы с разными датами/группами, если они
/// относятся к одной и той же бумаге.
class _TickerPlanSummary {
  final String ticker;
  final String name;
  final AssetType type;
  final double totalQty;
  final double totalEstimated;
  final int planCount;
  final bool allHavePrice;

  _TickerPlanSummary({
    required this.ticker,
    required this.name,
    required this.type,
    required this.totalQty,
    required this.totalEstimated,
    required this.planCount,
    required this.allHavePrice,
  });
}

/// Планы, объединённые по общему сроку (targetDate). Планы без срока
/// объединяются в отдельную псевдо-группу с key == _PlanGroup.noDateKey.
class _PlanGroup {
  static const noDateKey = '_none';

  final String key;
  final DateTime? date; // null = "без срока"
  final List<Plan> plans;

  _PlanGroup(this.key, this.date, this.plans);

  double get totalEstimated => plans.fold(0.0, (s, p) => s + (p.estimatedTotal ?? 0));
  bool get allHavePrice => plans.every((p) => p.targetPrice != null);
  int get doneCount => plans.where((p) => p.status == PlanStatus.done).length;

  PlanStatus get status {
    if (plans.every((p) => p.status == PlanStatus.done)) return PlanStatus.done;
    if (plans.every((p) => p.status == PlanStatus.cancelled)) return PlanStatus.cancelled;
    return PlanStatus.active;
  }
}

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _dateFormat = DateFormat('dd.MM.yyyy');

  final Set<String> _expandedKeys = {};
  bool _summaryExpanded = false;
  _DatePreset _preset = _DatePreset.all;
  DateTimeRange? _customRange;

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

  String _pluralBumaga(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'бумаг';
    if (mod10 == 1) return 'бумага';
    if (mod10 >= 2 && mod10 <= 4) return 'бумаги';
    return 'бумаг';
  }

  String _pluralPokupka(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'покупок';
    if (mod10 == 1) return 'покупка';
    if (mod10 >= 2 && mod10 <= 4) return 'покупки';
    return 'покупок';
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

  List<_PlanGroup> _groupPlans(List<Plan> plans) {
    final map = <String, List<Plan>>{};
    final dateOf = <String, DateTime?>{};
    for (final p in plans) {
      final d = p.targetDate;
      final key = d == null ? _PlanGroup.noDateKey : DateFormat('yyyy-MM-dd').format(d);
      map.putIfAbsent(key, () => []).add(p);
      dateOf[key] = d == null ? null : DateTime(d.year, d.month, d.day);
    }
    final groups = map.entries.map((e) => _PlanGroup(e.key, dateOf[e.key], e.value)).toList();
    groups.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });
    return groups;
  }

  bool _groupMatchesFilter(_PlanGroup g) {
    if (g.date == null) return true; // "без срока" фильтром по дате не скрываем
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_preset) {
      case _DatePreset.all:
        return true;
      case _DatePreset.thisMonth:
        return g.date!.year == now.year && g.date!.month == now.month;
      case _DatePreset.next3Months:
        final end = DateTime(now.year, now.month + 3, now.day);
        return !g.date!.isBefore(today) && !g.date!.isAfter(end);
      case _DatePreset.overdue:
        return g.date!.isBefore(today) && g.status != PlanStatus.done;
      case _DatePreset.custom:
        if (_customRange == null) return true;
        return !g.date!.isBefore(_customRange!.start) && !g.date!.isAfter(_customRange!.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = StorageService.plans;
    final allGroups = _groupPlans(all);
    final visibleGroups = allGroups.where(_groupMatchesFilter).toList();

    final activeGroups = visibleGroups.where((g) => g.status == PlanStatus.active).toList();
    final doneGroups = visibleGroups.where((g) => g.status == PlanStatus.done).toList();
    final cancelledGroups = visibleGroups.where((g) => g.status == PlanStatus.cancelled).toList();

    // Итог по выбранному периоду: все планы из видимых (после фильтра по
    // дате) групп, кроме отменённых — они больше не считаются "планом".
    final periodPlans = visibleGroups.expand((g) => g.plans).where((p) => p.status != PlanStatus.cancelled).toList();
    final periodTotal = periodPlans.fold(0.0, (s, p) => s + (p.estimatedTotal ?? 0));
    final periodAllHavePrice = periodPlans.isNotEmpty && periodPlans.every((p) => p.targetPrice != null);
    final periodByTicker = _summarizeByTicker(periodPlans);

    return Scaffold(
      appBar: AppBar(title: const Text('Планы покупок')),
      body: all.isEmpty
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
          : Column(
              children: [
                _filterBar(),
                Expanded(
                  child: visibleGroups.isEmpty
                      ? Center(
                          child: Text(
                            'Нет планов за выбранный период',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                          children: [
                            if (periodPlans.isNotEmpty) ...[
                              _periodSummaryCard(periodPlans, periodTotal, periodAllHavePrice, periodByTicker),
                              const SizedBox(height: 4),
                            ],
                            if (activeGroups.isNotEmpty) ...[
                              _sectionHeader('Ожидают', activeGroups.length),
                              ...activeGroups.map(_groupCard),
                              const SizedBox(height: 12),
                            ],
                            if (doneGroups.isNotEmpty) ...[
                              _sectionHeader('Выполнено', doneGroups.length),
                              ...doneGroups.map(_groupCard),
                              const SizedBox(height: 12),
                            ],
                            if (cancelledGroups.isNotEmpty) ...[
                              _sectionHeader('Отменено', cancelledGroups.length),
                              ...cancelledGroups.map(_groupCard),
                            ],
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('План'),
      ),
    );
  }

  Widget _filterBar() {
    final custom = _preset == _DatePreset.custom;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Все'),
              selected: _preset == _DatePreset.all,
              onSelected: (_) => setState(() => _preset = _DatePreset.all),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Этот месяц'),
              selected: _preset == _DatePreset.thisMonth,
              onSelected: (_) => setState(() => _preset = _DatePreset.thisMonth),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Ближайшие 3 мес'),
              selected: _preset == _DatePreset.next3Months,
              onSelected: (_) => setState(() => _preset = _DatePreset.next3Months),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Просрочено'),
              selected: _preset == _DatePreset.overdue,
              onSelected: (_) => setState(() => _preset = _DatePreset.overdue),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(Icons.date_range, size: 16, color: custom ? Colors.white : null),
              label: Text(
                custom && _customRange != null
                    ? '${_dateFormat.format(_customRange!.start)} – ${_dateFormat.format(_customRange!.end)}'
                    : 'Диапазон…',
                style: custom ? const TextStyle(color: Colors.white) : null,
              ),
              backgroundColor: custom ? Theme.of(context).colorScheme.primary : null,
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 2),
                  lastDate: DateTime(now.year + 5),
                  initialDateRange: _customRange,
                );
                if (picked != null) {
                  setState(() {
                    _customRange = picked;
                    _preset = _DatePreset.custom;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  List<_TickerPlanSummary> _summarizeByTicker(List<Plan> plans) {
    final map = <String, _TickerPlanSummary>{};
    for (final p in plans) {
      final estimated = p.estimatedTotal ?? 0;
      final existing = map[p.ticker];
      if (existing == null) {
        map[p.ticker] = _TickerPlanSummary(
          ticker: p.ticker,
          name: p.name,
          type: p.type,
          totalQty: p.targetQuantity,
          totalEstimated: estimated,
          planCount: 1,
          allHavePrice: p.targetPrice != null,
        );
      } else {
        map[p.ticker] = _TickerPlanSummary(
          ticker: existing.ticker,
          name: existing.name,
          type: existing.type,
          totalQty: existing.totalQty + p.targetQuantity,
          totalEstimated: existing.totalEstimated + estimated,
          planCount: existing.planCount + 1,
          allHavePrice: existing.allHavePrice && p.targetPrice != null,
        );
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.totalEstimated.compareTo(a.totalEstimated));
    return list;
  }

  String _presetLabel() {
    switch (_preset) {
      case _DatePreset.all:
        return 'за всё время';
      case _DatePreset.thisMonth:
        return 'в этом месяце';
      case _DatePreset.next3Months:
        return 'в ближайшие 3 мес';
      case _DatePreset.overdue:
        return '(просроченные)';
      case _DatePreset.custom:
        return _customRange != null
            ? 'за ${_dateFormat.format(_customRange!.start)} – ${_dateFormat.format(_customRange!.end)}'
            : 'за выбранный период';
    }
  }

  /// Сводная карточка "Итого по плану за период" — сверху списка, визуально
  /// того же стиля, что и карточки групп ниже, но с цветной заливкой/рамкой,
  /// чтобы явно выделяться на их фоне. Раскрывается тапом, показывая планы,
  /// просуммированные по каждой бумаге за выбранный период.
  Widget _periodSummaryCard(
    List<Plan> periodPlans,
    double periodTotal,
    bool allHavePrice,
    List<_TickerPlanSummary> byTicker,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: primary.withOpacity(0.08),
        border: Border.all(color: primary.withOpacity(0.35), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: primary.withOpacity(0.18), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(Icons.summarize_outlined, color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Итого по плану ${_presetLabel()}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${periodPlans.length} ${_pluralPokupka(periodPlans.length)} · ${byTicker.length} ${_pluralBumaga(byTicker.length)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        periodTotal > 0 ? '≈${periodTotal.toStringAsFixed(0)} ₽' : '—',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primary),
                      ),
                      if (periodTotal > 0 && !allHavePrice)
                        Text('не для всех задана цена', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(_summaryExpanded ? Icons.expand_less : Icons.expand_more, color: primary),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  Divider(color: primary.withOpacity(0.2), height: 1),
                  const SizedBox(height: 8),
                  ...byTicker.map((t) => _summaryTickerRow(t, primary)),
                ],
              ),
            ),
            crossFadeState: _summaryExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _summaryTickerRow(_TickerPlanSummary t, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          TickerAvatar(ticker: t.ticker, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.ticker} — ${t.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_typeLabel(t.type)} • ${t.totalQty.toStringAsFixed(t.totalQty == t.totalQty.roundToDouble() ? 0 : 2)} шт'
                  '${t.planCount > 1 ? " · ${t.planCount} план." : ""}'
                  '${t.totalEstimated > 0 && !t.allHavePrice ? " · не для всех цена" : ""}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            t.totalEstimated > 0 ? '≈${t.totalEstimated.toStringAsFixed(0)} ₽' : '—',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: accent),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(_PlanGroup g) {
    final expanded = _expandedKeys.contains(g.key);
    final status = g.status;
    final color = _statusColor(status, context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expanded) {
                _expandedKeys.remove(g.key);
              } else {
                _expandedKeys.add(g.key);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(g.date == null ? Icons.all_inbox : Icons.event, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.date == null ? 'Без срока' : 'к ${_dateFormat.format(g.date!)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${g.plans.length} ${_pluralBumaga(g.plans.length)}'
                          '${g.totalEstimated > 0 ? " · ≈${g.totalEstimated.toStringAsFixed(0)} ₽" : ""}'
                          '${g.totalEstimated > 0 && !g.allHavePrice ? " (не для всех задана цена)" : ""}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      status == PlanStatus.done
                          ? 'Выполнено'
                          : status == PlanStatus.cancelled
                              ? 'Отменено'
                              : '${g.doneCount}/${g.plans.length}',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) {
                      if (v == 'delete_group') _confirmDeleteGroup(g);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete_group', child: Text('Удалить группу')),
                    ],
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(children: g.plans.map(_planCard).toList()),
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _planCard(Plan p) {
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
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
                    '${p.estimatedTotal != null ? " (≈${p.estimatedTotal!.toStringAsFixed(0)})" : ""}'
                    '${p.note?.isNotEmpty == true ? "\n${p.note}" : ""}',
                  ),
                  isThreeLine: p.note?.isNotEmpty == true,
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

  Future<void> _confirmDeleteGroup(_PlanGroup g) async {
    final label = g.date == null ? 'без срока' : 'на дату ${_dateFormat.format(g.date!)}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: Text(
          'Будет удалено ${g.plans.length} ${_pluralBumaga(g.plans.length)} $label — без возможности восстановления.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      for (final p in g.plans) {
        await StorageService.deletePlan(p.id);
      }
      _expandedKeys.remove(g.key);
      setState(() {});
    }
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
        builder: (ctx, setSheetState) {
          final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: keyboardHeight + 16),
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
                if (keyboardHeight == 0) ...[
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
              ],
            ),
          );
        },
      ),
    );
  }
}
