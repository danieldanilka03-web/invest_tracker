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

  // --- Deposits ---
  static List<Deposit> get deposits => depositsBox.values.toList();
  static Future<void> addDeposit(Deposit d) => depositsBox.put(d.id, d);
  static Future<void> deleteDeposit(String id) => depositsBox.delete(id);

  // --- Purchases ---
  static List<Purchase> get purchases => purchasesBox.values.toList();
  static Future<void> addPurchase(Purchase p) => purchasesBox.put(p.id, p);
  static Future<void> deletePurchase(String id) => purchasesBox.delete(id);

  // --- Incomes ---
  static List<Income> get incomes => incomesBox.values.toList();
  static Future<void> addIncome(Income i) => incomesBox.put(i.id, i);
  static Future<void> deleteIncome(String id) => incomesBox.delete(id);

  // --- Plans ---
  static List<Plan> get plans => plansBox.values.toList();
  static Future<void> addPlan(Plan p) => plansBox.put(p.id, p);
  static Future<void> deletePlan(String id) => plansBox.delete(id);
  static Future<void> updatePlan(Plan p) => p.save();
}
