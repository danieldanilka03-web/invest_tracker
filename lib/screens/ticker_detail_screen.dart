import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../design/charts.dart';
import '../design/fields.dart';
import '../design/format.dart';
import '../design/motion.dart';
import '../design/surfaces.dart';
import '../design/tokens.dart';
import '../models/income.dart';
import '../models/purchase.dart';
import '../services/analytics_service.dart';
import '../services/favorites_service.dart';
import '../services/logo_service.dart';
import '../services/manual_price_service.dart';
import '../services/sector_service.dart';
import '../services/storage_service.dart';
import '../services/tax_service.dart';
import '../widgets/ticker_avatar.dart';

/// Карточка одной бумаги: сводка позиции, история цены, льгота ЛДВ,
/// полученные выплаты и все сделки — плюс быстрые кнопки «купить/продать».
class TickerDetailScreen extends StatefulWidget {
  final String ticker;
  const TickerDetailScreen({super.key, required this.ticker});

  @override
  State<TickerDetailScreen> createState() => _TickerDetailScreenState();
}

class _TickerDetailScreenState extends State<TickerDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final ticker = widget.ticker;
    final purchases = StorageService.purchases.where((p) => p.ticker == ticker).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final holding = AnalyticsService.currentHoldings()[ticker];
    final forecast = holding != null ? AnalyticsService.dividendForecastByTicker()[ticker] : null;
    final incomes = StorageService.incomes.where((i) => i.ticker == ticker).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final incomeTotal = incomes.fold<double>(0, (s, i) => s + i.amountNet);
    final openLots = (holding != null && TaxService.enabled)
        ? TaxService.openLotsForTicker(ticker)
        : <OpenLotInfo>[];
    final taxBreakdown = TaxService.enabled ? TaxService.saleTaxBreakdown() : <String, SaleTaxResult>{};
    final priceHistory = ManualPriceService.historyFor(ticker);
    final name = purchases.isNotEmpty ? purchases.first.name : ticker;
    final sector = SectorService.sectorFor(ticker);

    final pnlColor = AppColors.pnl(holding?.pnlRub ?? 0);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _appBar(context, ticker, name, sector, holding, pnlColor),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (holding == null && purchases.isNotEmpty)
                  const InfoBanner(
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.neutral,
                    text: 'Позиция закрыта — бумаги в портфеле нет. История сделок ниже сохранена.',
                  ),

                if (holding != null) ...[
                  FadeSlideIn(
                    child: IntrinsicHeight(
                        child: Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: 'В портфеле',
                            icon: Icons.inventory_2_outlined,
                            text: '${Fmt.qty(holding.qty)} шт',
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            label: 'Средняя цена',
                            icon: Icons.straighten_rounded,
                            text: holding.avgCost.toStringAsFixed(2),
                            color: AppColors.violet,
                          ),
                        ),
                      ],
                    ),
                      ),
                  ),
                  const SizedBox(height: 10),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 60),
                    child: IntrinsicHeight(
                        child: Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: holding.hasManualPrice ? 'Текущая цена' : 'Последняя цена',
                            icon: Icons.edit_rounded,
                            text: holding.displayPrice.toStringAsFixed(2),
                            hint: 'нажми, чтобы уточнить',
                            color: context.accent,
                            onTap: () => _showSetPriceDialog(context, ticker, holding),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatTile(
                            label: 'Прибыль / убыток',
                            icon: holding.pnlRub >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            text: '${Fmt.signedMoney(holding.pnlRub)} · ${Fmt.pct(holding.pnlPct)}',
                            color: pnlColor,
                          ),
                        ),
                      ],
                    ),
                      ),
                  ),
                  const SizedBox(height: 14),
                ],

                if (openLots.isNotEmpty) ...[
                  _ldvCard(openLots),
                  const SizedBox(height: 14),
                ],

                _priceHistoryCard(priceHistory, ticker),

                if (incomes.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SectionTitle(
                    title: 'Дивиденды и купоны',
                    subtitle: '${incomes.length} ${Fmt.payouts(incomes.length)}',
                    trailing: Text(
                      Fmt.signedMoney(incomeTotal),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.positive),
                    ),
                  ),
                  if (forecast != null && forecast.hasHistory) ...[
                    InfoBanner(
                      icon: Icons.auto_graph_rounded,
                      color: AppColors.violet,
                      text: 'Ожидаемый доход за 12 мес: ~${Fmt.money(forecast.last12mRub)} '
                          '(доходность ~${forecast.yieldPct.toStringAsFixed(1)}%) — по прошлым выплатам, не гарантия',
                    ),
                    const SizedBox(height: 10),
                  ],
                  ...incomes.map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(11),
                                  color: AppColors.positive.withOpacity(0.14),
                                ),
                                child: Icon(
                                  i.type == IncomeType.dividend
                                      ? Icons.trending_up_rounded
                                      : Icons.receipt_long_rounded,
                                  size: 18,
                                  color: AppColors.positive,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      i.type == IncomeType.dividend ? 'Дивиденд' : 'Купон',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      Fmt.date(i.date),
                                      style: TextStyle(fontSize: 11.5, color: context.dim),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '+${i.amountNet.toStringAsFixed(2)} ${i.currency == 'RUB' ? '₽' : i.currency}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: AppColors.positive,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],

                const SizedBox(height: 22),
                SectionTitle(
                  title: 'Сделки по бумаге',
                  subtitle: '${purchases.length} ${Fmt.deals(purchases.length)}',
                ),
                if (purchases.isEmpty)
                  Text('Сделок по этой бумаге пока нет', style: TextStyle(fontSize: 13, color: context.dim))
                else
                  ...purchases.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _tradeRow(p, p.isSell ? taxBreakdown[p.id] : null),
                      )),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: 'Продать',
                  icon: Icons.arrow_upward_rounded,
                  colors: const [Color(0xFFE23A5B), Color(0xFFFF6B85)],
                  onPressed: () => _quickTradeSheet(context, ticker, name, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  label: 'Купить',
                  icon: Icons.arrow_downward_rounded,
                  colors: const [Color(0xFF0FA97E), Color(0xFF16D796)],
                  onPressed: () => _quickTradeSheet(context, ticker, name, false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Шапка-«обложка»: аватарка бумаги, название, сектор и крупная текущая
  /// цена. При прокрутке сжимается в обычный компактный заголовок.
  Widget _appBar(
    BuildContext context,
    String ticker,
    String name,
    String sector,
    HoldingInfo? holding,
    Color pnlColor,
  ) {
    final accent = context.accent;
    final isFav = FavoritesService.isFavorite(ticker);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 244,
      backgroundColor: context.isDark ? AppColors.darkBg : AppColors.lightBg,
      surfaceTintColor: Colors.transparent,
      title: Text(ticker, style: const TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        IconButton(
          tooltip: isFav ? 'Убрать из избранного' : 'В избранное',
          icon: Icon(
            isFav ? Icons.star_rounded : Icons.star_border_rounded,
            color: isFav ? AppColors.gold : null,
          ),
          onPressed: () async {
            await FavoritesService.toggle(ticker);
            if (mounted) setState(() {});
          },
        ),
        IconButton(
          tooltip: 'Иконка бумаги',
          icon: const Icon(Icons.image_outlined),
          onPressed: () => _showLogoOptions(context, ticker),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withOpacity(context.isDark ? 0.34 : 0.20),
                    (context.isDark ? AppColors.darkBg : AppColors.lightBg).withOpacity(0.1),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _pickLogo(context, ticker),
                          onLongPress: () => _showLogoOptions(context, ticker),
                          child: Hero(tag: 'logo-$ticker', child: TickerAvatar(ticker: ticker, size: 56)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              TagChip(text: sector, color: accent, fontSize: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (holding != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RollingNumber(
                            value: holding.valueRub,
                            formatter: (v) => Fmt.money(v),
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: TagChip(
                              text: '${Fmt.pct(holding.pnlPct)} · ${Fmt.signedMoney(holding.pnlRub)}',
                              color: pnlColor,
                              icon: holding.pnlRub >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Бумаги нет в портфеле',
                        style: TextStyle(fontSize: 13, color: context.dim, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// График цены по датам. Точки берутся из истории ручных цен — туда же
  /// автоматически попадает цена каждой сделки, так что даже без ручного
  /// ввода график показывает реальную динамику по сделкам.
  Widget _priceHistoryCard(List<PricePoint> history, String ticker) {
    if (history.isEmpty) {
      return const InfoBanner(
        icon: Icons.show_chart_rounded,
        color: AppColors.info,
        text: 'История цены появится после первой сделки или когда укажешь текущую цену вручную.',
      );
    }

    final first = history.first;
    final last = history.last;
    final change = history.length > 1 ? last.price - first.price : 0.0;
    final changePct = history.length > 1 && first.price != 0 ? (change / first.price) * 100 : 0.0;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('История цены', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      history.length > 1
                          ? '${Fmt.date(first.date)} — ${Fmt.date(last.date)}'
                          : 'Отметка от ${Fmt.date(last.date)}',
                      style: TextStyle(fontSize: 11, color: context.dim),
                    ),
                  ],
                ),
              ),
              if (history.length > 1)
                TagChip(
                  text: '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} · ${Fmt.pct(changePct)}',
                  color: AppColors.pnl(change),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (history.length > 1)
            Sparkline(
              values: history.map((p) => p.price).toList(),
              color: context.accent,
              height: 150,
              tooltipBuilder: (i, v) => '${v.toStringAsFixed(2)}\n${Fmt.date(history[i].date)}',
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '${last.price.toStringAsFixed(2)} — добавь ещё одну отметку в другой день, '
                'чтобы увидеть график',
                style: TextStyle(fontSize: 12, color: context.dim),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ldvCard(List<OpenLotInfo> lots) {
    final waiting = lots.where((l) => !l.ldvActive).toList();
    if (waiting.isEmpty) {
      return const InfoBanner(
        icon: Icons.verified_rounded,
        color: AppColors.positive,
        text: 'Льгота на долгосрочное владение (ЛДВ) действует на всю позицию — '
            'прибыль с продажи не облагается налогом',
      );
    }
    waiting.sort((a, b) => a.daysUntilLdv.compareTo(b.daysUntilLdv));
    final nearest = waiting.first;
    return InfoBanner(
      icon: Icons.hourglass_bottom_rounded,
      color: AppColors.warning,
      text: 'До льготы ЛДВ по части позиции (${Fmt.qty(nearest.qty)} шт) '
          'осталось ${nearest.daysUntilLdv} дн.',
    );
  }

  Widget _tradeRow(Purchase p, SaleTaxResult? tax) {
    final color = p.isSell ? AppColors.negative : AppColors.positive;
    return AppCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: color.withOpacity(0.14),
            ),
            child: Icon(
              p.isSell ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.isSell ? 'Продажа' : 'Покупка'} · ${Fmt.qty(p.quantity)} шт × ${p.pricePerUnit}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(Fmt.date(p.date), style: TextStyle(fontSize: 11.5, color: context.dim)),
                if (tax != null && _taxLabel(tax) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: TagChip(text: _taxLabel(tax)!, color: AppColors.warning, fontSize: 9.5),
                  ),
              ],
            ),
          ),
          Text(
            '${p.isSell ? '+' : '−'}${Fmt.group(p.total)} ${p.currency == 'RUB' ? '₽' : p.currency}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: p.isSell ? color : null),
          ),
        ],
      ),
    );
  }

  String? _taxLabel(SaleTaxResult r) {
    if (r.realizedGainRub <= 0) return 'без налога (убыток)';
    if (r.taxableGainRub <= 0 && r.hasLdvPortion) return 'без налога (ЛДВ)';
    if (r.taxRub > 0) return 'налог ~${Fmt.money(r.taxRub)}';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Действия
  // ---------------------------------------------------------------------------

  /// Быстрая сделка прямо со страницы бумаги: тикер, тип, валюта и сектор
  /// берутся из последней сделки, чтобы не вводить их заново.
  Future<void> _quickTradeSheet(BuildContext context, String ticker, String name, bool isSell) async {
    final prior = StorageService.purchases.where((p) => p.ticker == ticker).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final type = prior.isNotEmpty ? prior.first.type : AssetType.stock;
    final currency = prior.isNotEmpty ? prior.first.currency : 'RUB';
    final sector = prior.isNotEmpty ? prior.first.sector : '';

    final qtyCtrl = TextEditingController();
    final knownPrice = ManualPriceService.get(ticker) ?? (prior.isNotEmpty ? prior.first.pricePerUnit : null);
    final priceCtrl = TextEditingController(text: knownPrice != null ? knownPrice.toString() : '');
    final feeCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();

    await showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final keyboard = MediaQuery.of(ctx).viewInsets.bottom;
          final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
          final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
          final fee = double.tryParse(feeCtrl.text.replaceAll(',', '.')) ?? 0;
          final sum = qty * price + (isSell ? -fee : fee);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 14, 20, keyboard + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(
                  title: isSell ? 'Продать $ticker' : 'Купить $ticker',
                  subtitle: name,
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: qtyCtrl,
                        label: 'Количество',
                        number: true,
                        autofocus: true,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: priceCtrl,
                        label: 'Цена ($currency)',
                        number: true,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: feeCtrl,
                        label: 'Комиссия',
                        number: true,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppDateField(
                        value: date,
                        label: 'Дата',
                        lastDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        onPicked: (d) => setSheetState(() => date = d),
                      ),
                    ),
                  ],
                ),
                if (sum > 0) ...[
                  const SizedBox(height: 12),
                  InfoBanner(
                    icon: Icons.calculate_outlined,
                    color: isSell ? AppColors.negative : AppColors.positive,
                    text: isSell
                        ? 'К зачислению примерно ${Fmt.group(sum)} $currency'
                        : 'Списание примерно ${Fmt.group(sum)} $currency',
                  ),
                ],
                const SizedBox(height: 12),
                AppTextField(controller: noteCtrl, label: 'Заметка (необязательно)'),
                const SizedBox(height: 22),
                GradientButton(
                  label: isSell ? 'Записать продажу' : 'Записать покупку',
                  icon: Icons.check_rounded,
                  colors: isSell
                      ? const [Color(0xFFE23A5B), Color(0xFFFF6B85)]
                      : const [Color(0xFF0FA97E), Color(0xFF16D796)],
                  onPressed: () async {
                    final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.'));
                    final pr = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                    if (q == null || pr == null || q <= 0 || pr <= 0) return;
                    final f = double.tryParse(feeCtrl.text.replaceAll(',', '.')) ?? 0;
                    await StorageService.addPurchase(Purchase(
                      id: const Uuid().v4(),
                      date: date,
                      ticker: ticker,
                      name: name,
                      type: type,
                      quantity: q,
                      pricePerUnit: pr,
                      fee: f,
                      currency: currency,
                      sector: sector,
                      isSell: isSell,
                      note: noteCtrl.text.isEmpty ? null : noteCtrl.text,
                    ));
                    // Цена сделки — реальное наблюдение цены на эту дату.
                    await ManualPriceService.setAt(ticker, date, pr);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickLogo(BuildContext context, String ticker) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;
    await LogoService.setLogo(ticker, File(picked.path));
    if (mounted) setState(() {});
  }

  Future<void> _showLogoOptions(BuildContext context, String ticker) async {
    final hasLogo = LogoService.getPath(ticker) != null;
    await showAppSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(title: 'Иконка бумаги', subtitle: 'Своя картинка вместо инициалов'),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(hasLogo ? 'Заменить иконку' : 'Загрузить иконку'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLogo(context, ticker);
                },
              ),
              if (hasLogo)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.negative),
                  title: const Text('Удалить иконку', style: TextStyle(color: AppColors.negative)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await LogoService.removeLogo(ticker);
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSetPriceDialog(BuildContext context, String ticker, HoldingInfo holding) async {
    final ctrl = TextEditingController(
      text: holding.hasManualPrice ? holding.displayPrice.toStringAsFixed(2) : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Текущая цена'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Приложение офлайн и не тянет котировки, поэтому по умолчанию берётся цена последней '
              'сделки. Укажи актуальную цену вручную — стоимость портфеля и графики пересчитаются честно.',
              style: TextStyle(color: context.dim, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: ctrl,
              label: 'Цена, ${holding.currency}',
              number: true,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          if (holding.hasManualPrice)
            TextButton(
              onPressed: () async {
                await ManualPriceService.clear(ticker);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
              child: const Text('Сбросить'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final price = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (price == null || price <= 0) return;
              await ManualPriceService.set(ticker, price);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
