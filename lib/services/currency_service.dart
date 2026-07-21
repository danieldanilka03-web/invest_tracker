import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Ручные курсы валют к рублю (базовая валюта статистики — RUB).
/// Курсы не тянутся из интернета (приложение офлайн) — пользователь
/// вводит их сам в настройках и обновляет по желанию.
/// Это упрощение: конвертация идёт по текущему введённому курсу,
/// а не по историческому курсу на дату сделки.
class CurrencyService {
  static const boxName = 'currency_rates';
  static late Box<double> _box;

  static final ValueNotifier<int> version = ValueNotifier(0);

  static const Map<String, double> _defaults = {
    'USD': 90.0,
    'EUR': 100.0,
    'CNY': 12.5,
  };

  static Future<void> init() async {
    _box = await Hive.openBox<double>(boxName);
    for (final e in _defaults.entries) {
      if (!_box.containsKey(e.key)) {
        await _box.put(e.key, e.value);
      }
    }
  }

  static double rateFor(String currency) {
    if (currency == 'RUB') return 1.0;
    return _box.get(currency, defaultValue: _defaults[currency] ?? 1.0) ?? 1.0;
  }

  static Future<void> setRate(String currency, double rate) async {
    await _box.put(currency, rate);
    version.value++;
  }

  /// Переводит сумму в валюте currency в рубли по сохранённому курсу
  static double toRub(double amount, String currency) => amount * rateFor(currency);

  static List<String> get trackedCurrencies => ['USD', 'EUR', 'CNY'];
}
