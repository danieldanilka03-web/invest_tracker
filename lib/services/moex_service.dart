import 'dart:convert';

import 'package:http/http.dart' as http;

/// Котировка одной бумаги, приведённая к рублям за штуку.
class MoexQuote {
  final String ticker;
  final String shortName;

  /// Цена в рублях за одну бумагу. Для облигаций уже пересчитана из процентов
  /// от номинала.
  final double price;

  /// Из какого поля ответа взята цена — нужно, чтобы в диагностике было видно,
  /// почему приехало именно это число.
  final String sourceField;

  final String board;
  final String market;

  /// Номинал облигации. Для акций и фондов — null.
  final double? faceValue;

  final DateTime fetchedAt;

  const MoexQuote({
    required this.ticker,
    required this.shortName,
    required this.price,
    required this.sourceField,
    required this.board,
    required this.market,
    required this.fetchedAt,
    this.faceValue,
  });

  bool get isBond => faceValue != null;
}

/// Понятная человеку ошибка загрузки: показывается в настройках как есть.
class MoexException implements Exception {
  final String message;
  const MoexException(this.message);

  @override
  String toString() => message;
}

/// Клиент ISS API Московской биржи (https://iss.moex.com) — публичного и
/// бесплатного, без ключа и регистрации.
///
/// Важное про данные: бесплатный доступ отдаёт котировки с задержкой (обычно
/// 15 минут), а вне торговой сессии — цену последнего торгового дня. Поэтому
/// время котировки нужно показывать пользователю, а не выдавать её за текущую.
class MoexService {
  MoexService._();

  static const _host = 'iss.moex.com';
  static const _timeout = Duration(seconds: 15);

  /// Режимы торгов, которые покрывают всё, что бывает в портфеле частного
  /// инвестора. Порядок важен: первое совпадение по тикеру выигрывает.
  static const List<({String market, String board})> boards = [
    (market: 'shares', board: 'TQBR'), // акции
    (market: 'shares', board: 'TQTF'), // биржевые фонды
    (market: 'bonds', board: 'TQCB'), // корпоративные облигации
    (market: 'bonds', board: 'TQOB'), // ОФЗ
  ];

  /// Колонки запрашиваем явно — ответ по всему режиму иначе весит сотни
  /// килобайт, а на мобильном интернете это заметно.
  static const _securitiesColumns = 'SECID,SHORTNAME,PREVPRICE,PREVLEGALCLOSEPRICE,FACEVALUE,LOTSIZE';
  static const _marketdataColumns = 'SECID,LAST,LCURRENTPRICE,MARKETPRICE,UPDATETIME';

  /// Загружает котировки по всем режимам и возвращает их по тикерам.
  ///
  /// Если [tickers] задан, лишнее отбрасывается — но запрос всё равно идёт
  /// целиком по режиму: четыре запроса на любой размер портфеля дешевле, чем
  /// по запросу на бумагу.
  static Future<Map<String, MoexQuote>> fetchQuotes({Set<String>? tickers}) async {
    final result = <String, MoexQuote>{};
    final errors = <String>[];

    for (final b in boards) {
      try {
        final quotes = await fetchBoard(market: b.market, board: b.board);
        for (final q in quotes) {
          if (tickers != null && !tickers.contains(q.ticker)) continue;
          // Первый режим, где бумага нашлась, и остаётся источником.
          result.putIfAbsent(q.ticker, () => q);
        }
      } catch (e) {
        errors.add('${b.board}: $e');
      }
    }

    // Полный провал — это ошибка. Если хотя бы один режим ответил, работаем с
    // тем, что есть: у пользователя может не быть облигаций вовсе.
    if (result.isEmpty && errors.isNotEmpty) {
      throw MoexException(errors.join('\n'));
    }
    return result;
  }

  /// Загружает один режим торгов целиком.
  static Future<List<MoexQuote>> fetchBoard({required String market, required String board}) async {
    final uri = Uri.https(_host, '/iss/engines/stock/markets/$market/boards/$board/securities.json', {
      'iss.meta': 'off',
      'iss.only': 'securities,marketdata',
      'securities.columns': _securitiesColumns,
      'marketdata.columns': _marketdataColumns,
    });

    final http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } catch (e) {
      throw MoexException('нет связи с биржей ($e)');
    }

    if (response.statusCode != 200) {
      throw MoexException('биржа ответила кодом ${response.statusCode}');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw MoexException('не удалось разобрать ответ биржи');
    }

    final securities = _table(json, 'securities');
    final marketdata = <String, Map<String, dynamic>>{
      for (final row in _table(json, 'marketdata'))
        if (row['SECID'] is String) row['SECID'] as String: row,
    };

    final now = DateTime.now();
    final isBondMarket = market == 'bonds';
    final quotes = <MoexQuote>[];

    for (final sec in securities) {
      final ticker = sec['SECID'];
      if (ticker is! String || ticker.isEmpty) continue;

      final md = marketdata[ticker] ?? const <String, dynamic>{};
      final faceValue = isBondMarket ? _toDouble(sec['FACEVALUE']) : null;

      // Приоритет: цена последней сделки, затем текущая расчётная, затем
      // рыночная, и лишь потом закрытие прошлого дня. Ночью и в выходные
      // живых сделок нет, поэтому запасные варианты обязательны.
      final candidates = <(String, double?)>[
        ('LAST', _toDouble(md['LAST'])),
        ('LCURRENTPRICE', _toDouble(md['LCURRENTPRICE'])),
        ('MARKETPRICE', _toDouble(md['MARKETPRICE'])),
        ('PREVPRICE', _toDouble(sec['PREVPRICE'])),
        ('PREVLEGALCLOSEPRICE', _toDouble(sec['PREVLEGALCLOSEPRICE'])),
      ];

      String? field;
      double? raw;
      for (final c in candidates) {
        if (c.$2 != null && c.$2! > 0) {
          field = c.$1;
          raw = c.$2;
          break;
        }
      }
      if (raw == null || field == null) continue;

      // Облигации на бирже котируются в процентах от номинала: 110,5 значит
      // 110,5% от 1000 ₽, то есть 1105 ₽. В приложении цены хранятся в рублях,
      // поэтому пересчитываем сразу здесь.
      final price = (isBondMarket && faceValue != null && faceValue > 0) ? raw * faceValue / 100 : raw;

      quotes.add(MoexQuote(
        ticker: ticker,
        shortName: (sec['SHORTNAME'] as String?) ?? ticker,
        price: price,
        sourceField: field,
        board: board,
        market: market,
        faceValue: faceValue,
        fetchedAt: now,
      ));
    }

    return quotes;
  }


  /// Тикеры валютных пар на бирже: расчёты «завтра» (TOM) — это основной
  /// торгуемый инструмент, по нему и считают курс.
  /// У одной и той же пары на бирже несколько идентификаторов, и набор со
  /// временем менялся. Перебираем известные варианты и берём первый, по
  /// которому пришла цена, — так не сломаемся от переименования.
  static const Map<String, List<String>> currencySecIds = {
    'USD': ['USD000UTSTOM', 'USDRUB_TOM', 'USD000000TOD'],
    'EUR': ['EUR_RUB__TOM', 'EURRUB_TOM', 'EUR_RUB__TOD'],
    'CNY': ['CNYRUB_TOM', 'CNY000000TOD'],
  };

  /// Текущие курсы валют с валютного рынка Мосбиржи.
  static Future<Map<String, double>> fetchCurrencyRates() async {
    final uri = Uri.https(_host, '/iss/engines/currency/markets/selt/boards/CETS/securities.json', {
      'iss.meta': 'off',
      'iss.only': 'securities,marketdata',
      'securities.columns': 'SECID,PREVPRICE',
      'marketdata.columns': 'SECID,LAST,MARKETPRICE',
    });

    final json = await _getJson(uri);
    final securities = <String, Map<String, dynamic>>{
      for (final row in _table(json, 'securities'))
        if (row['SECID'] is String) row['SECID'] as String: row,
    };
    final marketdata = <String, Map<String, dynamic>>{
      for (final row in _table(json, 'marketdata'))
        if (row['SECID'] is String) row['SECID'] as String: row,
    };

    final result = <String, double>{};
    currencySecIds.forEach((currency, candidates) {
      for (final secId in candidates) {
        final md = marketdata[secId] ?? const <String, dynamic>{};
        final sec = securities[secId] ?? const <String, dynamic>{};
        final rate = _toDouble(md['LAST']) ?? _toDouble(md['MARKETPRICE']) ?? _toDouble(sec['PREVPRICE']);
        if (rate != null && rate > 0) {
          result[currency] = rate;
          break;
        }
      }
    });
    return result;
  }

  /// История закрытий: используется для графиков на вкладке «Биржа».
  /// [path] — раздел ISS, [secId] — инструмент.
  static Future<List<MapEntry<DateTime, double>>> _fetchHistory({
    required String path,
    required DateTime from,
  }) async {
    final points = <MapEntry<DateTime, double>>[];
    // ISS отдаёт историю страницами по 100 строк.
    for (int start = 0; start < 1000; start += 100) {
      final uri = Uri.https(_host, path, {
        'iss.meta': 'off',
        'iss.only': 'history',
        'history.columns': 'TRADEDATE,CLOSE',
        'from': '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}',
        'start': '$start',
      });
      final rows = _table(await _getJson(uri), 'history');
      if (rows.isEmpty) break;
      for (final r in rows) {
        final date = DateTime.tryParse('${r['TRADEDATE']}');
        final close = _toDouble(r['CLOSE']);
        if (date != null && close != null && close > 0) {
          points.add(MapEntry(date, close));
        }
      }
      if (rows.length < 100) break;
    }
    points.sort((a, b) => a.key.compareTo(b.key));
    return points;
  }

  /// История индекса МосБиржи (IMOEX).
  static Future<List<MapEntry<DateTime, double>>> fetchIndexHistory({required DateTime from}) =>
      _fetchHistory(
        path: '/iss/history/engines/stock/markets/index/boards/SNDX/securities/IMOEX.json',
        from: from,
      );

  /// История курса валюты.
  static Future<List<MapEntry<DateTime, double>>> fetchCurrencyHistory(
    String currency, {
    required DateTime from,
  }) async {
    for (final secId in currencySecIds[currency] ?? const <String>[]) {
      try {
        final points = await _fetchHistory(
          path: '/iss/history/engines/currency/markets/selt/boards/CETS/securities/$secId.json',
          from: from,
        );
        if (points.isNotEmpty) return points;
      } catch (_) {
        // Пробуем следующий идентификатор пары.
      }
    }
    return const [];
  }

  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await http.get(uri).timeout(_timeout);
    } catch (e) {
      throw MoexException('нет связи с биржей ($e)');
    }
    if (response.statusCode != 200) {
      throw MoexException('биржа ответила кодом ${response.statusCode}');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw MoexException('не удалось разобрать ответ биржи');
    }
  }

  /// Разбирает блок ISS вида {"columns": [...], "data": [[...], ...]} в список
  /// словарей. Колонки читаем по именам, а не по позициям: биржа может
  /// добавить поле, и жёсткие индексы тогда разъедутся.
  static List<Map<String, dynamic>> _table(Map<String, dynamic> json, String key) {
    final block = json[key];
    if (block is! Map) return const [];
    final columns = block['columns'];
    final data = block['data'];
    if (columns is! List || data is! List) return const [];

    final names = columns.map((c) => '$c').toList();
    final rows = <Map<String, dynamic>>[];
    for (final row in data) {
      if (row is! List) continue;
      final map = <String, dynamic>{};
      for (int i = 0; i < names.length && i < row.length; i++) {
        map[names[i]] = row[i];
      }
      rows.add(map);
    }
    return rows;
  }

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }
}
