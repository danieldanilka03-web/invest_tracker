import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'services/favorites_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await ThemeService.init();
  await FavoritesService.init();
  runApp(const InvestTrackerApp());
}

class InvestTrackerApp extends StatelessWidget {
  const InvestTrackerApp({super.key});

  ThemeData _buildTheme(Color seed, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF7F7FA)
          : const Color(0xFF121214),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        height: 64,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
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
              home: const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
