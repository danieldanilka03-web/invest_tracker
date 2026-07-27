import 'package:flutter/material.dart';
import '../services/portfolio_service.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import 'home_screen.dart';

/// Главная страница приложения: список всех портфелей, разделённых по
/// статусу (активные/закрытые), со сводкой по активным портфелям сверху.
/// Тап по портфелю делает его активным и открывает его (обычный экран с
/// вкладками) — весь остальной интерфейс дальше работает с этим портфелем.
class PortfoliosScreen extends StatefulWidget {
  const PortfoliosScreen({super.key});

  @override
  State<PortfoliosScreen> createState() => _PortfoliosScreenState();
}

class _PortfolioStat {
  final double valueRub;
  final double profitRub;
  const _PortfolioStat({required this.valueRub, required this.profitRub});
}

class _PortfoliosScreenState extends State<PortfoliosScreen> {
  Map<String, _PortfolioStat> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PortfolioService.version.addListener(_onPortfoliosChanged);
    _load();
  }

  @override
  void dispose() {
    PortfolioService.version.removeListener(_onPortfoliosChanged);
    super.dispose();
  }

  void _onPortfoliosChanged() => _load();

  Future<void> _load() async {
    final list = PortfolioService.list;
    final stats = <String, _PortfolioStat>{};
    for (final p in list) {
      final data = await StorageService.readDataFor(p.id);
      final summary = AnalyticsService.summaryFor(purchases: data.purchases, incomes: data.incomes);
      stats[p.id] = _PortfolioStat(valueRub: summary.valueRub, profitRub: summary.profitRub);
    }
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  Future<void> _openPortfolio(PortfolioMeta p) async {
    if (p.id != PortfolioService.activeId) {
      await PortfolioService.switchTo(p.id);
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    // Пока пользователь был внутри портфеля, он мог что-то купить/продать —
    // по возвращении сюда пересчитываем стоимость и прибыль заново.
    _load();
  }

  Future<void> _createDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый портфель'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await PortfolioService.create(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(PortfolioMeta p) async {
    final ctrl = TextEditingController(text: p.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать портфель'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              await PortfolioService.rename(p.id, ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(PortfolioMeta p, int totalCount) async {
    if (totalCount <= 1) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить портфель?'),
        content: Text(
          'Все сделки, доходы, планы и секторы портфеля "${p.name}" будут удалены без возможности восстановления.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      await PortfolioService.delete(p.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = PortfolioService.list;
    final activeList = list.where((p) => p.status == PortfolioStatus.active).toList();
    final closedList = list.where((p) => p.status == PortfolioStatus.closed).toList();

    final activeValue = activeList.fold(0.0, (s, p) => s + (_stats[p.id]?.valueRub ?? 0));
    final activeProfit = activeList.fold(0.0, (s, p) => s + (_stats[p.id]?.profitRub ?? 0));

    return Scaffold(
      appBar: AppBar(title: const Text('Портфели')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Создать'),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('Портфелей нет', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _createDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Создать портфель'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _summaryCard(activeValue, activeProfit, activeList.length),
                const SizedBox(height: 20),
                if (activeList.isNotEmpty) ...[
                  _sectionHeader('Активные', activeList.length),
                  ...activeList.map((p) => _portfolioCard(p, list.length)),
                  const SizedBox(height: 12),
                ],
                if (closedList.isNotEmpty) ...[
                  _sectionHeader('Закрытые', closedList.length),
                  ...closedList.map((p) => _portfolioCard(p, list.length)),
                ],
              ],
            ),
    );
  }

  Widget _summaryCard(double value, double profit, int count) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [const Color(0xFF101B3D), primary, primary.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: primary.withOpacity(.28), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активные портфели ($count)',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else ...[
            Text(
              '${value.toStringAsFixed(0)} ₽',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  profit >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: profit >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${profit >= 0 ? "+" : ""}${profit.toStringAsFixed(0)} ₽ прибыли',
                  style: TextStyle(
                    color: profit >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        '$title · $count',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _portfolioCard(PortfolioMeta p, int totalCount) {
    final isSelected = p.id == PortfolioService.activeId;
    final isClosed = p.status == PortfolioStatus.closed;
    final stat = _stats[p.id];
    final profitColor = (stat?.profitRub ?? 0) >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      scale: isSelected ? 1 : .985,
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.4), width: 1.2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openPortfolio(p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
                child: Icon(isSelected ? Icons.check_rounded : Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (isSelected) _tag('Текущий', Theme.of(context).colorScheme.primary),
                        _tag(isClosed ? 'Закрыт' : 'Активен', isClosed ? Colors.grey.shade600 : Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (_loading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else if (stat != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${stat.valueRub.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${stat.profitRub >= 0 ? "+" : ""}${stat.profitRub.toStringAsFixed(0)} ₽',
                      style: TextStyle(fontSize: 12, color: profitColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') _renameDialog(p);
                  if (v == 'close') PortfolioService.setStatus(p.id, PortfolioStatus.closed);
                  if (v == 'reopen') PortfolioService.setStatus(p.id, PortfolioStatus.active);
                  if (v == 'delete') _confirmDelete(p, totalCount);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                  if (isClosed)
                    const PopupMenuItem(value: 'reopen', child: Text('Открыть заново'))
                  else
                    const PopupMenuItem(value: 'close', child: Text('Закрыть портфель')),
                  if (totalCount > 1)
                    const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
