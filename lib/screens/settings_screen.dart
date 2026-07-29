import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../design/fields.dart';
import '../design/format.dart';
import '../design/motion.dart';
import '../design/surfaces.dart';
import '../design/tokens.dart';
import '../services/analytics_service.dart';
import '../services/auto_backup_service.dart';
import '../services/backup_service.dart';
import '../services/backup_settings_service.dart';
import '../services/currency_service.dart';
import '../services/moex_service.dart';
import '../services/moex_sync_service.dart';
import '../services/online_settings_service.dart';
import '../services/sector_service.dart';
import '../services/tax_service.dart';
import '../services/theme_service.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            Text('Настройки', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(
              'Оформление, курсы, налоги и резервные копии',
              style: TextStyle(fontSize: 12, color: context.dim),
            ),
            const SizedBox(height: 18),

            // --- Оформление ---
            FadeSlideIn(
              child: _section(
                title: 'Оформление',
                subtitle: 'Акцентный цвет и тема',
                icon: Icons.palette_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<Color>(
                      valueListenable: ThemeService.accentColor,
                      builder: (context, current, _) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: kPalettes.map((p) {
                          final selected = p.color.value == current.value;
                          return Pressable(
                            onTap: () => ThemeService.setAccentColor(p.color),
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: AppDuration.normal,
                                  curve: Curves.easeOutBack,
                                  width: selected ? 50 : 44,
                                  height: selected ? 50 : 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppGradient.accent(p.color),
                                    border: Border.all(
                                      color: selected
                                          ? (context.isDark ? Colors.white : Colors.black87)
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: p.color.withOpacity(selected ? 0.5 : 0.25),
                                        blurRadius: selected ? 18 : 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 58,
                                  child: Text(
                                    p.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                      color: selected ? null : context.dim,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeService.themeMode,
                      builder: (context, mode, _) => SegmentedToggle<ThemeMode>(
                        values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                        selected: mode,
                        labelOf: (m) => switch (m) {
                          ThemeMode.system => 'Авто',
                          ThemeMode.light => 'Светлая',
                          ThemeMode.dark => 'Тёмная',
                        },
                        iconOf: (m) => switch (m) {
                          ThemeMode.system => Icons.brightness_auto_rounded,
                          ThemeMode.light => Icons.light_mode_rounded,
                          ThemeMode.dark => Icons.dark_mode_rounded,
                        },
                        onChanged: ThemeService.setThemeMode,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --- Курсы валют ---
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: _section(
                title: 'Курсы валют',
                subtitle: 'Задаются вручную — приложение работает офлайн',
                icon: Icons.currency_exchange_rounded,
                child: Column(
                  children: [
                    Text(
                      'Каждая сделка пересчитывается по курсу на её дату, поэтому для честной '
                      'статистики по старым сделкам стоит добавить исторический курс.',
                      style: TextStyle(fontSize: 11.5, height: 1.45, color: context.dim),
                    ),
                    const SizedBox(height: 14),
                    ...CurrencyService.trackedCurrencies.map((c) => _CurrencyCard(currency: c)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --- Онлайн-данные ---
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _section(
                title: 'Онлайн-данные',
                subtitle: 'Котировки с Московской биржи',
                icon: Icons.cloud_download_outlined,
                child: const _OnlineDataSection(),
              ),
            ),

            const SizedBox(height: 14),

            // --- Секторы ---
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: _section(
                title: 'Секторы',
                subtitle: 'Используются в диаграмме распределения',
                icon: Icons.pie_chart_outline_rounded,
                child: const _SectorsSection(),
              ),
            ),

            const SizedBox(height: 14),

            // --- Налог ---
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: _section(
                title: 'Налог с продажи (НДФЛ)',
                subtitle: 'Ставка и льгота на долгосрочное владение',
                icon: Icons.receipt_long_rounded,
                child: ValueListenableBuilder<int>(
                  valueListenable: TaxService.version,
                  builder: (context, _, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ставка применяется к прибыли от продажи бумаг, купленных менее 3 лет назад. '
                        'Владение от 3 лет освобождается от налога (ЛДВ) — упрощённо, без лимита суммы.',
                        style: TextStyle(fontSize: 11.5, height: 1.45, color: context.dim),
                      ),
                      const SizedBox(height: 12),
                      _switchRow(
                        title: 'Показывать налог с продаж',
                        subtitle: 'Расчёт НДФЛ и ЛДВ на главной и в карточке бумаги',
                        value: TaxService.enabled,
                        onChanged: TaxService.setEnabled,
                      ),
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        duration: AppDuration.normal,
                        opacity: TaxService.enabled ? 1 : 0.4,
                        child: IgnorePointer(
                          ignoring: !TaxService.enabled,
                          child: SegmentedToggle<double>(
                            values: const [0.13, 0.15],
                            selected: TaxService.rate,
                            labelOf: (r) => '${(r * 100).toStringAsFixed(0)}%',
                            onChanged: TaxService.setRate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --- Данные ---
            FadeSlideIn(
              delay: const Duration(milliseconds: 180),
              child: _section(
                title: 'Данные',
                subtitle: 'Резервные копии и восстановление',
                icon: Icons.save_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _actionRow(
                      icon: Icons.ios_share_rounded,
                      title: 'Экспортировать бэкап',
                      subtitle: 'Сохранить все данные в JSON-файл',
                      onTap: () => BackupService.exportToJson(),
                    ),
                    const SizedBox(height: 8),
                    _actionRow(
                      icon: Icons.file_download_outlined,
                      title: 'Импортировать бэкап',
                      subtitle: 'Восстановить данные из ранее сохранённого файла',
                      onTap: () => _importBackup(context),
                    ),
                    const SizedBox(height: 18),
                    const _AutoBackupSection(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),
            Center(
              child: Column(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 18, color: context.dim),
                  const SizedBox(height: 8),
                  Text(
                    'Все данные хранятся только на этом устройстве.\nНикакого интернета и облака.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.dim, fontSize: 11.5, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kListBottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final accent = context.accent;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.26), accent.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: context.dim)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11.3, height: 1.35, color: context.dim)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withOpacity(0.035) : AppColors.lightSurfaceHigh,
          borderRadius: AppRadius.all(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.3, color: context.dim)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: context.dim),
          ],
        ),
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
              '${Fmt.plural(result.missingLogos.length, "иконка", "иконки", "иконок")} '
              '(${result.missingLogos.keys.join(", ")}). Часто причина в том, что проводник Android '
              'открывает временную копию файла, а не саму папку. Выбрать папку с иконками вручную?',
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
}

/// Карточка одной валюты: текущий курс и разворачиваемая история по датам.
class _CurrencyCard extends StatefulWidget {
  final String currency;
  const _CurrencyCard({required this.currency});

  @override
  State<_CurrencyCard> createState() => _CurrencyCardState();
}

class _CurrencyCardState extends State<_CurrencyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CurrencyService.version,
      builder: (context, _, __) {
        final history = CurrencyService.historyFor(widget.currency);
        final current = CurrencyService.currentRate(widget.currency);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withOpacity(0.035) : AppColors.lightSurfaceHigh,
            borderRadius: AppRadius.all(AppRadius.sm),
          ),
          child: Column(
            children: [
              Pressable(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: context.accent.withOpacity(0.14),
                        ),
                        child: Text(
                          widget.currency,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.accent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${current.toStringAsFixed(2)} ₽',
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${history.length} ${Fmt.plural(history.length, "отметка", "отметки", "отметок")} в истории',
                              style: TextStyle(fontSize: 11, color: context.dim),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: AppDuration.fast,
                        child: Icon(Icons.expand_more_rounded, color: context.dim),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...history.reversed.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 86,
                                  child: Text(Fmt.date(p.date), style: TextStyle(fontSize: 11.5, color: context.dim)),
                                ),
                                Expanded(
                                  child: Text(
                                    '${p.rate.toStringAsFixed(2)} ₽',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 15),
                                  onPressed: () => _showRateDialog(context, initialDate: p.date, initialRate: p.rate),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (history.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 15),
                                    onPressed: () => CurrencyService.deleteRateAt(widget.currency, p.date),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showRateDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Добавить курс на дату'),
                      ),
                    ],
                  ),
                ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: AppDuration.normal,
                sizeCurve: Curves.easeInOut,
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
              AppDateField(
                value: date,
                label: 'Дата',
                lastDate: DateTime.now(),
                firstDate: DateTime(2010),
                onPicked: (d) => setDialogState(() => date = d),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: ctrl, label: 'Курс, ₽', number: true, autofocus: true),
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

/// Управление секторами: создание/удаление и привязка бумаг.
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
            if (customSectors.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: customSectors
                    .map((s) => Chip(
                          label: Text(s),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          onDeleted: () => _confirmDeleteSector(context, s),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(child: AppTextField(controller: _newSectorCtrl, label: 'Новый сектор')),
                const SizedBox(width: 10),
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
            Text(
              'Привязка бумаг',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.dim),
            ),
            const SizedBox(height: 10),
            if (ownedTickers.isEmpty)
              Text(
                'Здесь появятся бумаги, которые ты покупал — их можно привязать к своим секторам.',
                style: TextStyle(fontSize: 11.5, height: 1.4, color: context.dim),
              )
            else
              ...ownedTickers.map((ticker) {
                final current = SectorService.sectorFor(ticker);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          ticker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                      ),
                      Expanded(
                        child: AppDropdown<String>(
                          value: availableSectors.contains(current) ? current : null,
                          label: 'Сектор',
                          hint: Text(current, style: TextStyle(fontSize: 13, color: context.dim)),
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
        content: Text('Бумаги, привязанные к «$sector», вернутся к сектору по умолчанию.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SectorService.removeSector(sector);
    }
  }
}

/// Автосохранение бэкапа: включение и выбор папки.
class _AutoBackupSection extends StatefulWidget {
  const _AutoBackupSection();

  @override
  State<_AutoBackupSection> createState() => _AutoBackupSectionState();
}

class _AutoBackupSectionState extends State<_AutoBackupSection> {
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
            Text(
              'Автосохранение бэкапа',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.dim),
            ),
            const SizedBox(height: 6),
            Text(
              'Приложение само сохраняет JSON-бэкап текущего портфеля в выбранную папку при каждом '
              'изменении данных. На некоторых версиях Android доступны для записи не все папки — '
              'если не срабатывает, попробуй «Загрузки».',
              style: TextStyle(fontSize: 11.3, height: 1.45, color: context.dim),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: context.isDark ? Colors.white.withOpacity(0.035) : AppColors.lightSurfaceHigh,
                borderRadius: AppRadius.all(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Автосохранение включено',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          path ?? 'Сначала выбери папку ниже',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: context.dim),
                        ),
                      ],
                    ),
                  ),
                  Switch(
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
                ],
              ),
            ),
            const SizedBox(height: 8),
            Pressable(
              onTap: _pickFolder,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withOpacity(0.035) : AppColors.lightSurfaceHigh,
                  borderRadius: AppRadius.all(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 20, color: context.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            path == null ? 'Выбрать папку' : 'Изменить папку',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          if (last != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Последнее сохранение: ${Fmt.date(last)} '
                                '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 11, color: context.dim),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: context.dim),
                  ],
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              InfoBanner(
                icon: Icons.error_outline_rounded,
                color: AppColors.negative,
                text: 'Последнее сохранение не удалось: $error\nПопробуй выбрать другую папку.',
              ),
            ],
          ],
        );
      },
    );
  }
}


/// Загрузка котировок с Мосбиржи. Пока это только проверка связи: цены
/// показываются в самой секции и никуда не сохраняются — так можно убедиться,
/// что биржа отвечает и числа разбираются верно, до того как они начнут
/// влиять на расчёты портфеля.
class _OnlineDataSection extends StatefulWidget {
  const _OnlineDataSection();

  @override
  State<_OnlineDataSection> createState() => _OnlineDataSectionState();
}

class _OnlineDataSectionState extends State<_OnlineDataSection> {
  bool _loading = false;
  String? _error;
  Map<String, MoexQuote> _quotes = {};
  List<String> _missing = [];

  Future<void> _check() async {
    final tickers = AnalyticsService.allOwnedTickers().toSet();
    setState(() {
      _loading = true;
      _error = null;
      _missing = [];
    });
    try {
      final quotes = await MoexService.fetchQuotes(tickers: tickers);
      await OnlineSettingsService.markSynced(quotes.length);
      if (!mounted) return;
      setState(() {
        _quotes = quotes;
        _missing = tickers.where((t) => !quotes.containsKey(t)).toList()..sort();
        _loading = false;
      });
    } catch (e) {
      await OnlineSettingsService.markError('$e');
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OnlineSettingsService.version,
      builder: (context, _, __) {
        final enabled = OnlineSettingsService.enabled;
        final last = OnlineSettingsService.lastSyncAt;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Приложение обращается только к iss.moex.com и только когда ты это разрешишь. '
              'Биржа отдаёт данные с задержкой около 15 минут, а вне торгов — цену последнего '
              'торгового дня, поэтому время котировки всегда показывается рядом с ней.',
              style: TextStyle(fontSize: 11.3, height: 1.45, color: context.dim),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: context.isDark ? Colors.white.withOpacity(0.035) : AppColors.lightSurfaceHigh,
                borderRadius: AppRadius.all(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Загружать котировки с биржи',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          last == null
                              ? 'Пока ни разу не загружалось'
                              : 'Последняя загрузка: ${Fmt.date(last)} '
                                  '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')} '
                                  '· бумаг: ${OnlineSettingsService.lastCount}',
                          style: TextStyle(fontSize: 11, color: context.dim),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) async {
                      await OnlineSettingsService.setEnabled(v);
                      MoexSyncService.instance.applySettings();
                    },
                  ),
                ],
              ),
            ),
            if (enabled) ...[
              const SizedBox(height: 14),
              Text(
                'Как часто обновлять',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.dim),
              ),
              const SizedBox(height: 8),
              SegmentedToggle<int>(
                values: const [10, 30, 60, 300],
                selected: OnlineSettingsService.intervalSeconds,
                labelOf: (v) => v < 60 ? '$v с' : '${v ~/ 60} мин',
                onChanged: (v) async {
                  await OnlineSettingsService.setIntervalSeconds(v);
                  MoexSyncService.instance.applySettings();
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Обновление идёт, только когда приложение открыто на экране. '
                'Биржа отдаёт данные с задержкой около 15 минут, так что интервал в 10 секунд '
                'почти не даёт свежести, но заметно расходует трафик и батарею.',
                style: TextStyle(fontSize: 11, height: 1.4, color: context.dim),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loading ? null : _check,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering_rounded, size: 18),
              label: Text(_loading ? 'Спрашиваю биржу…' : 'Проверить связь'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              InfoBanner(
                icon: Icons.cloud_off_rounded,
                color: AppColors.negative,
                text: 'Не получилось: $_error',
              ),
            ],
            if (_quotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Ответ биржи',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.dim),
              ),
              const SizedBox(height: 8),
              ...(_quotes.values.toList()..sort((a, b) => a.ticker.compareTo(b.ticker))).map(
                (q) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 108,
                        child: Text(
                          q.ticker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Fmt.money(q.price, decimals: 2),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            Text(
                              '${q.board} · ${q.sourceField}'
                              '${q.faceValue != null ? " · номинал ${Fmt.money(q.faceValue!, decimals: 0)}" : ""}',
                              style: TextStyle(fontSize: 10.5, color: context.dim),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_missing.isNotEmpty) ...[
              const SizedBox(height: 6),
              InfoBanner(
                icon: Icons.help_outline_rounded,
                color: AppColors.warning,
                text: 'Не нашлись на бирже: ${_missing.join(", ")}. '
                    'Скорее всего, бумага торгуется в другом режиме — пришли мне этот список, добавлю режим.',
              ),
            ],
          ],
        );
      },
    );
  }
}
