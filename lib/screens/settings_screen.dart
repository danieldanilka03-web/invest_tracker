import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/theme_service.dart';
import '../services/backup_service.dart';
import '../services/backup_settings_service.dart';
import '../services/auto_backup_service.dart';
import '../services/currency_service.dart';
import '../services/tax_service.dart';
import '../services/sector_service.dart';
import '../services/analytics_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text('Персонализация', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -.4)),
          const SizedBox(height: 4),
          Text('Настрой приложение под свой стиль', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 24),
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
            'Приложение офлайн и не тянет котировки из интернета — курсы задаются вручную. '
            'Каждая сделка конвертируется по курсу, действовавшему на её дату, поэтому для честной '
            'статистики по старым сделкам стоит добавить исторический курс на нужную дату.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...CurrencyService.trackedCurrencies.map((cur) => _CurrencyRateCard(currency: cur)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Секторы', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Создай свои секторы и привяжи к ним бумаги — это используется в графике '
            '"Распределение по секторам" на главном экране. У бумаги может быть только один сектор.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),
          const _SectorsSection(),
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
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Импортировать бэкап'),
              subtitle: const Text('Восстановить данные из ранее сохранённого JSON-файла'),
              onTap: () => _importBackup(context),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Автосохранение бэкапа', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'Приложение само сохраняет JSON-бэкап текущего портфеля в выбранную папку при каждом изменении '
            'данных — без диалогов и подтверждений. На некоторых версиях Android доступны для автозаписи не '
            'все папки — если сохранение не срабатывает, попробуй выбрать другую (например, папку "Загрузки" '
            'или папку внутри собственного хранилища приложения).',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),
          const _AutoBackupSection(),
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

  Future<void> _importBackup(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Импорт бэкапа'),
        content: const Text(
          'Данные из файла будут добавлены к тем, что уже есть в приложении '
          '(существующие записи не удаляются и не перезаписываются). Продолжить?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выбрать файл')),
        ],
      ),
    );
    if (confirm != true) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null || picked.files.single.path == null) return;

    try {
      final result = await BackupService.importFromFilePath(picked.files.single.path!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортировано записей: ${result.count}')),
      );
      setState(() {});

      if (result.missingLogos.isNotEmpty) {
        if (!context.mounted) return;
        final wantsManualPick = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Не нашлись иконки бумаг'),
            content: Text(
              'Рядом с файлом бэкапа не нашлось ${result.missingLogos.length} '
              '${_pluralIcon(result.missingLogos.length)} (${result.missingLogos.keys.join(", ")}). '
              'Часто причина в том, что системный проводник Android открывает временную копию файла, '
              'а не саму папку, где он лежит. Выбрать папку с иконками вручную?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Пропустить')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выбрать папку')),
            ],
          ),
        );
        if (wantsManualPick == true) {
          final folder = await FilePicker.platform.getDirectoryPath();
          if (folder != null) {
            final fixed = await BackupService.retryMissingLogos(result.missingLogos, folder);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(fixed > 0 ? 'Подтянуто иконок: $fixed' : 'В этой папке иконки не нашлись')),
            );
            setState(() {});
          }
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось прочитать файл: $e')),
      );
    }
  }

  String _pluralIcon(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'иконок';
    if (mod10 == 1) return 'иконка';
    if (mod10 >= 2 && mod10 <= 4) return 'иконки';
    return 'иконок';
  }
}

/// Карточка одной валюты: текущий курс + разворачиваемая история по датам
class _CurrencyRateCard extends StatefulWidget {
  final String currency;
  const _CurrencyRateCard({required this.currency});

  @override
  State<_CurrencyRateCard> createState() => _CurrencyRateCardState();
}

class _CurrencyRateCardState extends State<_CurrencyRateCard> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CurrencyService.version,
      builder: (context, _, __) {
        final history = CurrencyService.historyFor(widget.currency);
        final current = CurrencyService.currentRate(widget.currency);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              ListTile(
                title: Text(widget.currency, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Текущий курс: ${current.toStringAsFixed(2)} ₽'),
                trailing: IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...history.reversed.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(width: 90, child: Text(_dateFormat.format(p.date), style: const TextStyle(fontSize: 12))),
                                Expanded(child: Text('${p.rate.toStringAsFixed(2)} ₽', style: const TextStyle(fontSize: 12))),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  onPressed: () => _showRateDialog(context, initialDate: p.date, initialRate: p.rate),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (history.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    onPressed: () => CurrencyService.deleteRateAt(widget.currency, p.date),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showRateDialog(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Добавить курс на дату'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRateDialog(BuildContext context, {DateTime? initialDate, double? initialRate}) async {
    DateTime date = initialDate ?? DateTime.now();
    final ctrl = TextEditingController(text: initialRate?.toStringAsFixed(2) ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Курс ${widget.currency}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
                child: Text(_dateFormat.format(date)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Курс, ₽', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                final rate = double.tryParse(ctrl.text.replaceAll(',', '.'));
                if (rate == null || rate <= 0) return;
                await CurrencyService.setRateAt(widget.currency, date, rate);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Секция управления секторами: создание/удаление секторов и привязка бумаг
class _SectorsSection extends StatefulWidget {
  const _SectorsSection();

  @override
  State<_SectorsSection> createState() => _SectorsSectionState();
}

class _SectorsSectionState extends State<_SectorsSection> {
  final _newSectorCtrl = TextEditingController();

  @override
  void dispose() {
    _newSectorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SectorService.version,
      builder: (context, _, __) {
        final customSectors = SectorService.customSectors;
        final ownedTickers = AnalyticsService.allOwnedTickers();
        final availableSectors = SectorService.allAvailableSectors;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Список пользовательских секторов ---
            if (customSectors.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: customSectors
                    .map((s) => Chip(
                          label: Text(s),
                          onDeleted: () => _confirmDeleteSector(context, s),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSectorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Новый сектор',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    if (_newSectorCtrl.text.trim().isEmpty) return;
                    await SectorService.addSector(_newSectorCtrl.text);
                    _newSectorCtrl.clear();
                  },
                  child: const Text('Добавить'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Привязка бумаг', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            if (ownedTickers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Появятся бумаги, которые ты уже покупал — привяжи их к секторам здесь.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              )
            else
              ...ownedTickers.map((ticker) {
                final current = SectorService.sectorFor(ticker);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 90, child: Text(ticker, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: availableSectors.contains(current) ? current : null,
                          hint: Text(current),
                          isExpanded: true,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Без сектора')),
                            ...availableSectors.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                          ],
                          onChanged: (v) => SectorService.assignSector(ticker, v),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteSector(BuildContext context, String sector) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить сектор?'),
        content: Text('Бумаги, привязанные к "$sector", вернутся к сектору по умолчанию.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm == true) {
      await SectorService.removeSector(sector);
    }
  }
}

/// Настройка автосохранения бэкапа: включение/выключение и выбор папки.
class _AutoBackupSection extends StatefulWidget {
  const _AutoBackupSection();

  @override
  State<_AutoBackupSection> createState() => _AutoBackupSectionState();
}

class _AutoBackupSectionState extends State<_AutoBackupSection> {
  final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;
    await BackupSettingsService.setFolderPath(path);
    await AutoBackupService.runNowIfEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BackupSettingsService.version,
      builder: (context, _, __) {
        final path = BackupSettingsService.folderPath;
        final enabled = BackupSettingsService.enabled;
        final last = BackupSettingsService.lastBackupAt;
        final error = BackupSettingsService.lastError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('Автосохранение включено'),
                subtitle: Text(path ?? 'Сначала выбери папку ниже'),
                value: enabled && path != null,
                onChanged: (v) async {
                  if (v && path == null) {
                    await _pickFolder();
                    if (BackupSettingsService.folderPath == null) return;
                  }
                  await BackupSettingsService.setEnabled(v);
                  if (v) await AutoBackupService.runNowIfEnabled();
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(path == null ? 'Выбрать папку' : 'Изменить папку'),
                subtitle: last != null ? Text('Последнее сохранение: ${_dateFormat.format(last)}') : null,
                onTap: _pickFolder,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Последнее сохранение не удалось: $error\nПопробуй выбрать другую папку (например, "Загрузки").',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
