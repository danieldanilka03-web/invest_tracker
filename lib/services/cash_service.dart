import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Свободные средства — деньги на счету, которые ещё не вложены в бумаги
/// (например, только что внесённые, или вырученные от продажи и не реинвестированные).
/// Задаются вручную пользователем — приложение офлайн и не видит баланс брокера.
class CashService {
  static const boxName = 'cash';
  static late Box<double> _box;

  static final ValueNotifier<int> version = ValueNotifier(0);

  static Future<void> init() async {
    _box = await Hive.openBox<double>(boxName);
  }

  static double get balance => _box.get('balance', defaultValue: 0.0) ?? 0.0;

  static Future<void> setBalance(double value) async {
    await _box.put('balance', value);
    version.value++;
  }

  static Future<void> adjust(double delta) async {
    await setBalance(balance + delta);
  }
}
