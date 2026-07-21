import 'package:hive/hive.dart';

part 'purchase.g.dart';

@HiveType(typeId: 1)
enum AssetType {
  @HiveField(0)
  stock, // акция
  @HiveField(1)
  bond, // облигация
  @HiveField(2)
  etf, // фонд
  @HiveField(3)
  currency, // валюта
  @HiveField(4)
  other,
}

/// Покупка (или продажа, если quantity отрицательное — опционально) актива
@HiveType(typeId: 2)
class Purchase extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  String ticker; // например SBER, AAPL, RU000A1023T8

  @HiveField(3)
  String name; // человекочитаемое имя

  @HiveField(4)
  AssetType type;

  @HiveField(5)
  double quantity;

  @HiveField(6)
  double pricePerUnit;

  @HiveField(7)
  double fee; // комиссия брокера

  @HiveField(8)
  String currency;

  @HiveField(9)
  String? note;

  @HiveField(10)
  String? sector; // сектор экономики, для статистики по отраслям

  Purchase({
    required this.id,
    required this.date,
    required this.ticker,
    required this.name,
    required this.type,
    required this.quantity,
    required this.pricePerUnit,
    this.fee = 0,
    this.currency = 'RUB',
    this.note,
    this.sector,
  });

  double get total => quantity * pricePerUnit + fee;
}
