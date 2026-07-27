import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/storage_service.dart';
import 'services/portfolio_service.dart';
import 'services/theme_service.dart';
import 'services/favorites_service.dart';
import 'services/currency_service.dart';
import 'services/tax_service.dart';
import 'services/sector_service.dart';
import 'services/manual_price_service.dart';
import 'services/logo_service.dart';
import 'services/backup_settings_service.dart';
import 'services/auto_backup_service.dart';
import 'screens/portfolios_screen.dart';

// Держим ссылку на верхнем уровне, чтобы слушатель жизненного цикла не был
// собран сборщиком мусора (AppLifecycleListener не привязан к дереву виджетов).
late final AppLifecycleListener _lifecycleListener;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  StorageService.registerAdapters();
  await PortfolioService.init(); // должен инициализироваться до StorageService/SectorService — они читают активный портфель
  await StorageService.init();
  await ThemeService.init();
  await FavoritesService.init();
  await CurrencyService.init();
  await TaxService.init();
  await SectorService.init();
  await ManualPriceService.init();
  await LogoService.init();
  await BackupSettingsService.init();
  AutoBackupService.attach();
  unawaited(AutoBackupService.runNowIfEnabled());

  // "Вход и выход из приложения" на Android/iOS обычно НЕ перезапускают
  // процесс (main() не вызывается заново) — это просто сворачивание/разворачивание,
  // поэтому одного запуска при старте недостаточно: без этого слушателя
  // автобэкап срабатывал только на настоящий холодный старт. resumed —
  // вернулись в приложение, paused/detached — свернули или закрыли.
  _lifecycleListener = AppLifecycleListener(
    onStateChange: (state) {
      if (state == AppLifecycleState.resumed ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        unawaited(AutoBackupService.runNowIfEnabled());
      }
    },
  );

  runApp(const InvestTrackerApp());
}

class InvestTrackerApp extends StatelessWidget {
  const InvestTrackerApp({super.key});

  ThemeData _buildTheme(Color seed, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF5F7FB),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        toolbarHeight: 72,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.7),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: isDark ? const Color(0xFF141C31) : Colors.white,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant.withOpacity(isDark ? .24 : .55)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF141C31) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(.55))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: isDark ? const Color(0xFF121A2E) : Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withOpacity(.55)),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        iconColor: scheme.primary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF141C31) : Colors.white,
        modalBackgroundColor: isDark ? const Color(0xFF141C31) : Colors.white,
        modalBarrierColor: const Color(0xFF081124).withOpacity(.48),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: isDark ? const Color(0xFF141C31) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 21, fontWeight: FontWeight.w800),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? const Color(0xFF1A243B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF24304D) : const Color(0xFF17233D),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme().apply(fontFamily: null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: ThemeService.accentColor,
      builder: (context, accent, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeMode,
          builder: (context, mode, _) {
            return MaterialApp(
              title: 'Invest Tracker',
              debugShowCheckedModeBanner: false,
              theme: _buildTheme(accent, Brightness.light),
              darkTheme: _buildTheme(accent, Brightness.dark),
              themeMode: mode,
              home: const PortfoliosScreen(),
            );
          },
        );
      },
    );
  }
}
