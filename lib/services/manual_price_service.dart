import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Вручную указанная "текущая цена" бумаги. Приложение офлайн и не тянет
/// котировки из интернета, поэтому по умолчанию используется цена последней
/// сделки — но если пользователь укажет актуальную цену вручную, она
/// приоритетнее и используется для оценки стоимости позиции и графиков.
class ManualPriceService {
  static const boxName = 'manual_prices';
  static late Box<double> _box;

  static final ValueNotifier<int> version = ValueNotifier(0);

  static Future<void> init() async {
    _box = await Hive.openBox<double>(boxName);
  }

  static double? get(String ticker) => _box.get(ticker.toUpperCase());

  static Future<void> set(String ticker, double price) async {
    await _box.put(ticker.toUpperCase(), price);
    version.value++;
  }

  static Future<void> clear(String ticker) async {
    await _box.delete(ticker.toUpperCase());
    version.value++;
  }

  /// Все ручные цены (для бэкапа)
  static Map<String, double> get all {
    final map = <String, double>{};
    for (final key in _box.keys) {
      final v = _box.get(key);
      if (v != null) map[key as String] = v;
    }
    return map;
  }
}
