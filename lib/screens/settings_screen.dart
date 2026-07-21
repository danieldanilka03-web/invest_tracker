import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Цветовая палитра', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ValueListenableBuilder<Color>(
            valueListenable: ThemeService.accentColor,
            builder: (context, current, _) => Wrap(
              spacing: 14,
              runSpacing: 14,
              children: kPalettes.map((p) {
                final selected = p.color.value == current.value;
                return GestureDetector(
                  onTap: () => ThemeService.setAccentColor(p.color),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.color,
                          border: selected
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: p.color.withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 6),
                      Text(p.name, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Тема', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeMode,
            builder: (context, mode, _) => SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Авто')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Светлая')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Тёмная')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => ThemeService.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Данные', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Экспортировать бэкап'),
              subtitle: const Text('Сохранить все данные в JSON-файл'),
              onTap: () => BackupService.exportToJson(),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Все данные хранятся только на этом устройстве.\nНикакого интернета и облака.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
