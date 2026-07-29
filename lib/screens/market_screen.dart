import 'package:flutter/material.dart';
import '../design/charts.dart';
import '../design/fields.dart';
import '../design/format.dart';
import '../design/motion.dart';
import '../design/surfaces.dart';
import '../design/tokens.dart';
import '../services/analytics_service.dart';
import '../services/currency_service.dart';
import '../services/favorites_service.dart';
import '../services/moex_service.dart';
import '../services/moex_sync_service.dart';
import '../services/online_price_service.dart';
import '../services/online_settings_service.dart';
import '../widgets/ticker_avatar.dart';
import 'home_screen.dart';
import 'ticker_detail_screen.dart';

enum _MarketFilter { all, shares, funds, bonds, owned, favorites }

enum _MarketSort { name, priceDesc, priceAsc }

/// Все бумаги, которые торгуются на Мосбирже, с котировками. Список приходит
/// из того же цикла обновления, что и цены портфеля, поэтому экран не ходит в
/// сеть отдельно — он просто показывает последний снимок рынка.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _searchCtrl = TextEditingController();

  /// Что показываем на графике: индекс МосБиржи или курс валюты.
  String _chartKey = 'IMOEX';
  List<MapEntry<DateTime, double>> _chartPoints = const [];
  bool _chartLoading = false;
  String? _chartError;
  String _query = '';
  _MarketFilter _filter = _MarketFilter.all;
  _MarketSort _sort = _MarketSort.name;

  @override
  void initState() {
    super.initState();
    if (OnlineSettingsService.enabled) _loadChart();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// История для графика грузится отдельно от котировок и редко: она меняется
  /// раз в день, тянуть её каждые десять секунд смысла нет.
  Future<void> _loadChart() async {
    setState(() {
      _chartLoading = true;
      _chartError = null;
    });
    final from = DateTime.now().subtract(const Duration(days: 180));
    try {
      final points = _chartKey == 'IMOEX'
          ? await MoexService.fetchIndexHistory(from: from)
          : await MoexService.fetchCurrencyHistory(_chartKey, from: from);
      if (!mounted) return;
      setState(() {
        _chartPoints = points;
        _chartLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chartError = '$e';
        _chartLoading = false;
      });
    }
  }

  static String _typeOf(String board) => switch (board) {
        'TQBR' => 'Акция',
        'TQTF' => 'Фонд',
        'TQCB' => 'Облигация',
        'TQOB' => 'ОФЗ',
        _ => 'Бумага',
      };

  static Color _typeColor(String board) => switch (board) {
        'TQBR' => AppColors.info,
        'TQTF' => AppColors.violet,
        'TQCB' => AppColors.gold,
        'TQOB' => AppColors.cyan,
        _ => AppColors.neutral,
      };

  bool _matchesFilter(MoexQuote q, Set<String> owned) => switch (_filter) {
        _MarketFilter.all => true,
        _MarketFilter.shares => q.board == 'TQBR',
        _MarketFilter.funds => q.board == 'TQTF',
        _MarketFilter.bonds => q.board == 'TQCB' || q.board == 'TQOB',
        _MarketFilter.owned => owned.contains(q.ticker),
        _MarketFilter.favorites => FavoritesService.isFavorite(q.ticker),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<int>(
          valueListenable: OnlineSettingsService.version,
          builder: (context, _, __) {
            if (!OnlineSettingsService.enabled) {
              return EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Загрузка с биржи выключена',
                subtitle: 'Включи её в настройках — и здесь появятся все бумаги Мосбиржи с котировками.',
                action: GradientButton(
                  label: 'Открыть настройки',
                  icon: Icons.tune_rounded,
                  expand: false,
                  onPressed: () => HomeScreen.goToSettings(context),
                ),
              );
            }

            return ValueListenableBuilder<Map<String, MoexQuote>>(
              valueListenable: MoexSyncService.marketSnapshot,
              builder: (context, snapshot, __) {
                final quotes = snapshot.isNotEmpty
                    ? snapshot.values.toList()
                    : OnlinePriceService.all.entries
                        .map((e) => MoexQuote(
                              ticker: e.key,
                              shortName: e.value.shortName,
                              price: e.value.price,
                              sourceField: 'cache',
                              board: e.value.board,
                              market: '',
                              fetchedAt: e.value.fetchedAt,
                            ))
                        .toList();

                return _body(quotes);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _body(List<MoexQuote> quotes) {
    // Именно текущие позиции: полностью проданная бумага в портфеле больше
    // не числится.
    final owned = AnalyticsService.currentHoldings().keys.toSet();
    final q = _query.trim().toUpperCase();

    final list = quotes.where((e) {
      if (!_matchesFilter(e, owned)) return false;
      if (q.isEmpty) return true;
      return e.ticker.toUpperCase().contains(q) || e.shortName.toUpperCase().contains(q);
    }).toList();

    list.sort(switch (_sort) {
      _MarketSort.name => (a, b) => a.ticker.compareTo(b.ticker),
      _MarketSort.priceDesc => (a, b) => b.price.compareTo(a.price),
      _MarketSort.priceAsc => (a, b) => a.price.compareTo(b.price),
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Биржа', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 2),
                    ValueListenableBuilder<bool>(
                      valueListenable: MoexSyncService.refreshing,
                      builder: (context, refreshing, _) {
                        final last = OnlineSettingsService.lastSyncAt;
                        return Row(
                          children: [
                            if (refreshing) ...[
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.6, color: context.accent),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              refreshing
                                  ? 'Обновляю…'
                                  : last == null
                                      ? '${quotes.length} бумаг'
                                      : '${quotes.length} бумаг · '
                                          '${last.hour.toString().padLeft(2, '0')}:'
                                          '${last.minute.toString().padLeft(2, '0')}:'
                                          '${last.second.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 12, color: context.dim),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Обновить сейчас',
                onPressed: () => MoexSyncService.instance.refreshNow(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: kListBottomPadding),
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              _ratesCard(),
              _chartCard(),
              const SizedBox(height: 6),
              _listHeader(list.length),
              for (int i = 0; i < list.length; i++)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, i == list.length - 1 ? 0 : 8),
                  child: _row(list[i], owned.contains(list[i].ticker)),
                ),
              if (list.isEmpty)
                EmptyState(
                  icon: quotes.isEmpty ? Icons.cloud_sync_outlined : Icons.search_off_rounded,
                  title: quotes.isEmpty ? 'Жду первую загрузку' : 'Ничего не нашлось',
                  subtitle: quotes.isEmpty
                      ? 'Котировки подтянутся через несколько секунд после запуска.'
                      : 'Попробуй другой запрос или сними фильтр.',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title: 'Бумаги', subtitle: '$count в списке'),
          AppSearchField(
            controller: _searchCtrl,
            hint: 'Тикер или название',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          PillTabs<_MarketFilter>(
          values: _MarketFilter.values,
          selected: _filter,
          labelOf: (f) => switch (f) {
            _MarketFilter.all => 'Все',
            _MarketFilter.shares => 'Акции',
            _MarketFilter.funds => 'Фонды',
            _MarketFilter.bonds => 'Облигации',
            _MarketFilter.owned => 'В портфеле',
            _MarketFilter.favorites => 'Избранное',
          },
            onChanged: (f) => setState(() => _filter = f),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          PillTabs<_MarketSort>(
          values: _MarketSort.values,
          selected: _sort,
          labelOf: (s) => switch (s) {
            _MarketSort.name => 'По тикеру',
            _MarketSort.priceDesc => 'Цена ↓',
            _MarketSort.priceAsc => 'Цена ↑',
          },
            onChanged: (s) => setState(() => _sort = s),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }


  Widget _ratesCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ValueListenableBuilder<int>(
        valueListenable: CurrencyService.version,
        builder: (context, _, __) => ValueListenableBuilder<Map<String, double>>(
          valueListenable: MoexSyncService.currencyRates,
          builder: (context, online, __) {
            return AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(
                    title: 'Курсы валют',
                    subtitle: 'Валютный рынок МосБиржи',
                    padding: EdgeInsets.only(bottom: 12),
                  ),
                  Row(
                    children: [
                      for (final c in CurrencyService.trackedCurrencies) ...[
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                c,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.dim,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (online[c] ?? CurrencyService.currentRate(c)).toStringAsFixed(2),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        if (c != CurrencyService.trackedCurrencies.last)
                          Container(width: 1, height: 32, color: context.hairline),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    online.isEmpty
                        ? 'Пока показаны курсы из настроек — биржевые подтянутся при первом обновлении.'
                        : 'Курс на дату сделки по-прежнему можно задать вручную в настройках.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, height: 1.35, color: context.dim),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chartCard() {
    final points = _chartPoints;
    final values = points.map((e) => e.value).toList();
    final change = values.length > 1 ? values.last - values.first : 0.0;
    final changePct = values.length > 1 && values.first != 0 ? change / values.first * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title: _chartKey == 'IMOEX' ? 'Индекс МосБиржи' : 'Курс $_chartKey',
              subtitle: 'Полгода, закрытие торгов',
              padding: const EdgeInsets.only(bottom: 10),
              trailing: values.length > 1
                  ? TagChip(
                      text: '${change >= 0 ? "+" : ""}${changePct.toStringAsFixed(1)}%',
                      color: AppColors.pnl(change),
                    )
                  : null,
            ),
            PillTabs<String>(
              values: const ['IMOEX', 'USD', 'EUR', 'CNY'],
              selected: _chartKey,
              labelOf: (k) => k == 'IMOEX' ? 'Индекс' : k,
              onChanged: (k) {
                setState(() => _chartKey = k);
                _loadChart();
              },
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 140,
              child: _chartLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _chartError != null
                      ? Center(
                          child: Text(
                            'График не загрузился: $_chartError',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: context.dim),
                          ),
                        )
                      : values.length < 2
                          ? Center(
                              child: Text('Нет данных', style: TextStyle(fontSize: 12, color: context.dim)),
                            )
                          : Sparkline(
                              values: values,
                              color: AppColors.pnl(change),
                              height: 140,
                              tooltipBuilder: (i, v) =>
                                  '${Fmt.date(points[i].key)} · ${v.toStringAsFixed(2)}',
                            ),
            ),
            if (values.length > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Fmt.date(points.first.key), style: TextStyle(fontSize: 10.5, color: context.dim)),
                  Text(
                    values.last.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  Text(Fmt.date(points.last.key), style: TextStyle(fontSize: 10.5, color: context.dim)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(MoexQuote q, bool isOwned) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        AppPageRoute(builder: (_) => TickerDetailScreen(ticker: q.ticker)),
      ),
      child: Row(
        children: [
          TickerAvatar(ticker: q.ticker, size: 38, glow: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        q.ticker,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    if (isOwned) ...[
                      const SizedBox(width: 6),
                      TagChip(text: 'в портфеле', color: AppColors.positive, fontSize: 9),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  q.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: context.dim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(q.price, decimals: q.price < 10 ? 3 : 2),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 3),
              TagChip(text: _typeOf(q.board), color: _typeColor(q.board), fontSize: 9),
            ],
          ),
          ValueListenableBuilder<int>(
            valueListenable: FavoritesService.version,
            builder: (context, _, __) {
              final fav = FavoritesService.isFavorite(q.ticker);
              return IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  fav ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: fav ? AppColors.gold : context.dim,
                ),
                onPressed: () => FavoritesService.toggle(q.ticker),
              );
            },
          ),
        ],
      ),
    );
  }
}
