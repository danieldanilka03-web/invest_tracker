import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../services/backup_service.dart';
import '../services/currency_service.dart';
import '../services/tax_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Map<String, TextEditingController> _rateCtrls;

  @override
  void initState() {
    super.initState();
    _rateCtrls = {
      for (final c in CurrencyService.trackedCurrencies)
        c: TextEditingController(text: CurrencyService.rateFor(c).toStringAsFixed(2)),
    };
  }

  @override
  void dispose() {
    for (final c in _rateCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

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
          const Text('Курсы валют', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Приложение офлайн и не тянет котировки из интернета — курсы задаются вручную '
            'и используются, чтобы сводить статистику по разным валютам в единую сумму (в рублях).',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...CurrencyService.trackedCurrencies.map((cur) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 50, child: Text(cur, style: const TextStyle(fontWeight: FontWeight.w600))),
                    const Text('=', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _rateCtrls[cur],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          suffixText: '₽',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          final rate = double.tryParse(v.replaceAll(',', '.'));
                          if (rate != null && rate > 0) {
                            CurrencyService.setRate(cur, rate);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Налог с продажи (НДФЛ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Ставка применяется к прибыли от продажи бумаг, купленных менее 3 лет назад. '
            'Владение от 3 лет освобождается от налога (льгота ЛДВ) — упрощённо, без лимита освобождаемой суммы.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: TaxService.version,
            builder: (context, _, __) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Показывать налог с продаж'),
              subtitle: const Text('Расчёт НДФЛ и льготы ЛДВ на главной и в деталях бумаги'),
              value: TaxService.enabled,
              onChanged: (v) => TaxService.setEnabled(v),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: TaxService.version,
            builder: (context, _, __) => Opacity(
              opacity: TaxService.enabled ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !TaxService.enabled,
                child: SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: 0.13, label: Text('13%')),
                    ButtonSegment(value: 0.15, label: Text('15%')),
                  ],
                  selected: {TaxService.rate},
                  onSelectionChanged: (s) => TaxService.setRate(s.first),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
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
