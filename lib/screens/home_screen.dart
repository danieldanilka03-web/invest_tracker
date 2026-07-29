import 'package:flutter/material.dart';
import '../design/nav_bar.dart';
import 'dashboard_screen.dart';
import 'invest_radar_screen.dart';
import 'purchases_screen.dart';
import 'incomes_screen.dart';
import 'plans_screen.dart';
import 'market_screen.dart';
import 'settings_screen.dart';

/// Каркас приложения внутри портфеля: семь вкладок в IndexedStack (чтобы
/// каждая сохраняла своё состояние — фильтры, позицию прокрутки) плюс
/// собственная анимированная навигация внизу.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Переключает на вкладку настроек из любого места внутри каркаса —
  /// нужно, например, экрану «Биржа», когда загрузка котировок выключена.
  static void goToSettings(BuildContext context) {
    context.findAncestorStateOfType<_HomeScreenState>()?._select(_settingsIndex);
  }

  static void goToPurchases(BuildContext context) {
    context.findAncestorStateOfType<_HomeScreenState>()?._select(_purchasesIndex);
  }

  static const _purchasesIndex = 3;
  static const _settingsIndex = 6;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Короткое проявление контента при смене вкладки: IndexedStack сам по
  /// себе переключается мгновенно, и без этой анимации переход выглядит
  /// «дёрганым» рядом с плавно едущей навигацией.
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);

  final _screens = const [
    DashboardScreen(),
    InvestRadarScreen(),
    MarketScreen(),
    PurchasesScreen(),
    IncomesScreen(),
    PlansScreen(),
    SettingsScreen(),
  ];

  static const _items = [
    NavItem(icon: Icons.donut_large_outlined, activeIcon: Icons.donut_large, label: 'Портфель'),
    NavItem(icon: Icons.radar_outlined, activeIcon: Icons.radar_rounded, label: 'Радар'),
    NavItem(icon: Icons.show_chart_rounded, activeIcon: Icons.show_chart_rounded, label: 'Биржа'),
    NavItem(icon: Icons.swap_horiz_outlined, activeIcon: Icons.swap_horiz, label: 'Сделки'),
    NavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Доход'),
    NavItem(icon: Icons.flag_outlined, activeIcon: Icons.flag, label: 'Планы'),
    NavItem(icon: Icons.tune_outlined, activeIcon: Icons.tune, label: 'Ещё'),
  ];

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _fade.forward(from: 0.35);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: AuroraNavBar(
        items: _items,
        index: _index,
        onChanged: _select,
      ),
    );
  }
}

/// Отступ снизу для списков внутри вкладок: под плавающей кнопкой действия
/// контент не должен «прятаться».
const double kListBottomPadding = 96;
