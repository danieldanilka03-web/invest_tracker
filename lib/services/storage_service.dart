import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/deposit.dart';
import '../models/purchase.dart';
import '../models/income.dart';
import '../models/plan.dart';

/// Единая точка доступа к локальному хранилищу.
/// Всё хранится в файлах Hive на диске устройства — без БД-сервера,
/// без интернета, полностью офлайн.
class StorageService {
  static const depositsBoxName = 'deposits';
  static const purchasesBoxName = 'purchases';
  static const incomesBoxName = 'incomes';
  static const plansBoxName = 'plans';

  static late Box<Deposit> depositsBox;
  static late Box<Purchase> purchasesBox;
  static late Box<Income> incomesBox;
  static late Box<Plan> plansBox;

  /// Увеличивается при любом изменении данных (покупка, продажа, доход, план).
  /// Экраны вроде дашборда слушают это значение через ValueListenableBuilder,
  /// чтобы автоматически перечитывать статистику без ручного refresh.
  static final ValueNotifier<int> dataVersion = ValueNotifier(0);

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(DepositAdapter());
    Hive.registerAdapter(AssetTypeAdapter());
    Hive.registerAdapter(PurchaseAdapter());
    Hive.registerAdapter(IncomeTypeAdapter());
    Hive.registerAdapter(IncomeAdapter());
    Hive.registerAdapter(PlanStatusAdapter());
    Hive.registerAdapter(PlanAdapter());

    depositsBox = await Hive.openBox<Deposit>(depositsBoxName);
    purchasesBox = await Hive.openBox<Purchase>(purchasesBoxName);
    incomesBox = await Hive.openBox<Income>(incomesBoxName);
    plansBox = await Hive.openBox<Plan>(plansBoxName);
  }

  static void _bump() => dataVersion.value++;

  // --- Deposits ---
  static List<Deposit> get deposits => depositsBox.values.toList();
  static Future<void> addDeposit(Deposit d) async {
    await depositsBox.put(d.id, d);
    _bump();
  }

  static Future<void> deleteDeposit(String id) async {
    await depositsBox.delete(id);
    _bump();
  }

  // --- Purchases ---
  static List<Purchase> get purchases => purchasesBox.values.toList();
  static Future<void> addPurchase(Purchase p) async {
    await purchasesBox.put(p.id, p);
    _bump();
  }

  static Future<void> deletePurchase(String id) async {
    await purchasesBox.delete(id);
    _bump();
  }

  // --- Incomes ---
  static List<Income> get incomes => incomesBox.values.toList();
  static Future<void> addIncome(Income i) async {
    await incomesBox.put(i.id, i);
    _bump();
  }

  static Future<void> deleteIncome(String id) async {
    await incomesBox.delete(id);
    _bump();
  }

  // --- Plans ---
  static List<Plan> get plans => plansBox.values.toList();
  static Future<void> addPlan(Plan p) async {
    await plansBox.put(p.id, p);
    _bump();
  }

  static Future<void> deletePlan(String id) async {
    await plansBox.delete(id);
    _bump();
  }

  static Future<void> updatePlan(Plan p) async {
    await p.save();
    _bump();
  }
}
