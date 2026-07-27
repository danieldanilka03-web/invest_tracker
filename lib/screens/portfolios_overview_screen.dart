import 'package:flutter/material.dart';
import '../services/portfolio_service.dart';
import '../services/portfolio_overview_service.dart';
import 'home_screen.dart';

/// Общая сводка по всем портфелям сразу — суммарная стоимость и прибыль,
/// плюс карточка на каждый портфель. Тап по портфелю переключает на него
/// и открывает обычный экран приложения (дашборд/покупки/...).
class PortfoliosOverviewScreen extends StatefulWidget {
  const PortfoliosOverviewScreen({super.key});

  @override
  State<PortfoliosOverviewScreen> createState() => _PortfoliosOverviewScreenState();
}

class _PortfoliosOverviewScreenState extends State<PortfoliosOverviewScreen> {
  late Future<List<PortfolioSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = PortfolioOverviewService.allSummaries();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = PortfolioOverviewService.allSummaries();
    });
    await _future;
  }

  Future<void> _openPortfolio(String id) async {
    await PortfolioService.switchTo(id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Все портфели')),
      body: FutureBuilder<List<PortfolioSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final summaries = snapshot.data!;
          final totalValue = summaries.fold(0.0, (s, x) => s + x.valueRub);
          final totalProfit = summaries.fold(0.0, (s, x) => s + x.profitRub);
          final primary = Theme.of(context).colorScheme.primary;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: totalValue),
                  builder: (context, value, _) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFF101B3D), primary, primary.withOpacity(0.72)],
                    ),
                    boxShadow: [
                      BoxShadow(color: primary.withOpacity(0.28), blurRadius: 28, offset: const Offset(0, 14)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Все портфели вместе', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        '${value.toStringAsFixed(0)} ₽',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            totalProfit >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            color: totalProfit >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Прибыль: ${totalProfit >= 0 ? "+" : ""}${totalProfit.toStringAsFixed(0)} ₽',
                            style: TextStyle(
                              color: totalProfit >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ),
                const SizedBox(height: 24),
                const Text('Портфели', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  'Тап по портфелю открывает его',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ...summaries.map((s) {
                  final isActive = s.meta.id == PortfolioService.activeId;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: isActive ? BorderSide(color: primary, width: 1.5) : BorderSide.none,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openPortfolio(s.meta.id),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(color: primary.withOpacity(0.12), shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Icon(Icons.account_balance_wallet_outlined, color: primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          s.meta.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: primary.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text('активный', style: TextStyle(fontSize: 10, color: primary)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.holdingsCount} ${_pluralBumaga(s.holdingsCount)} в портфеле',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${s.valueRub.toStringAsFixed(0)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  '${s.profitRub >= 0 ? "+" : ""}${s.profitRub.toStringAsFixed(0)} ₽',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: s.profitRub >= 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  String _pluralBumaga(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'бумаг';
    if (mod10 == 1) return 'бумага';
    if (mod10 >= 2 && mod10 <= 4) return 'бумаги';
    return 'бумаг';
  }
}
