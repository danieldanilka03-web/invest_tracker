import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/deposit.dart';
import '../models/purchase.dart';
import '../models/income.dart';
import '../models/plan.dart';
import 'storage_service.dart';
import 'sector_service.dart';
import 'manual_price_service.dart';
import 'currency_service.dart';

/// Экспорт/импорт всех данных в один JSON-файл.
/// Так как БД нет, это единственный способ сделать бэкап
/// или перенести данные на новый телефон.
class BackupService {
  static Future<String> exportToJson() async {
    final data = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'deposits': StorageService.deposits
          .map((d) => {
                'id': d.id,
                'date': d.date.toIso8601String(),
                'amount': d.amount,
                'currency': d.currency,
                'note': d.note,
                'broker': d.broker,
              })
          .toList(),
      'purchases': StorageService.purchases
          .map((p) => {
                'id': p.id,
                'date': p.date.toIso8601String(),
                'ticker': p.ticker,
                'name': p.name,
                'type': p.type.index,
                'quantity': p.quantity,
                'pricePerUnit': p.pricePerUnit,
                'fee': p.fee,
                'currency': p.currency,
                'note': p.note,
                'sector': p.sector,
                'isSell': p.isSell,
              })
          .toList(),
      'incomes': StorageService.incomes
          .map((i) => {
                'id': i.id,
                'date': i.date.toIso8601String(),
                'ticker': i.ticker,
                'name': i.name,
                'type': i.type.index,
                'amountGross': i.amountGross,
                'taxPaid': i.taxPaid,
                'currency': i.currency,
                'note': i.note,
              })
          .toList(),
      'plans': StorageService.plans
          .map((p) => {
                'id': p.id,
                'ticker': p.ticker,
                'name': p.name,
                'type': p.type.index,
                'targetQuantity': p.targetQuantity,
                'targetPrice': p.targetPrice,
                'targetDate': p.targetDate?.toIso8601String(),
                'status': p.status.index,
                'note': p.note,
                'createdAt': p.createdAt.toIso8601String(),
              })
          .toList(),
      'customSectors': SectorService.customSectors,
      'sectorAssignments': SectorService.allAssignments,
      'manualPrices': ManualPriceService.all,
      'currencyRateHistory': {
        for (final c in CurrencyService.trackedCurrencies)
          c: CurrencyService.historyFor(c).map((p) => p.toJson()).toList(),
      },
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'invest_tracker_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles([XFile(file.path)], text: 'Бэкап Invest Tracker');

    return file.path;
  }

  static Future<int> importFromFilePath(String path) async {
    final content = await File(path).readAsString();
    return importFromJson(content);
  }

  static Future<int> importFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    int count = 0;

    for (final d in (data['deposits'] as List? ?? [])) {
      await StorageService.addDeposit(Deposit(
        id: d['id'],
        date: DateTime.parse(d['date']),
        amount: (d['amount'] as num).toDouble(),
        currency: d['currency'] ?? 'RUB',
        note: d['note'],
        broker: d['broker'],
      ));
      count++;
    }

    for (final p in (data['purchases'] as List? ?? [])) {
      await StorageService.addPurchase(Purchase(
        id: p['id'],
        date: DateTime.parse(p['date']),
        ticker: p['ticker'],
        name: p['name'],
        type: AssetType.values[p['type']],
        quantity: (p['quantity'] as num).toDouble(),
        pricePerUnit: (p['pricePerUnit'] as num).toDouble(),
        fee: (p['fee'] as num?)?.toDouble() ?? 0,
        currency: p['currency'] ?? 'RUB',
        note: p['note'],
        sector: p['sector'],
        isSell: p['isSell'] ?? false,
      ));
      count++;
    }

    for (final i in (data['incomes'] as List? ?? [])) {
      await StorageService.addIncome(Income(
        id: i['id'],
        date: DateTime.parse(i['date']),
        ticker: i['ticker'],
        name: i['name'],
        type: IncomeType.values[i['type']],
        amountGross: (i['amountGross'] as num).toDouble(),
        taxPaid: (i['taxPaid'] as num?)?.toDouble() ?? 0,
        currency: i['currency'] ?? 'RUB',
        note: i['note'],
      ));
      count++;
    }

    for (final p in (data['plans'] as List? ?? [])) {
      await StorageService.addPlan(Plan(
        id: p['id'],
        ticker: p['ticker'],
        name: p['name'],
        type: AssetType.values[p['type']],
        targetQuantity: (p['targetQuantity'] as num).toDouble(),
        targetPrice: (p['targetPrice'] as num?)?.toDouble(),
        targetDate:
            p['targetDate'] != null ? DateTime.parse(p['targetDate']) : null,
        status: PlanStatus.values[p['status']],
        note: p['note'],
        createdAt: DateTime.parse(p['createdAt']),
      ));
      count++;
    }

    for (final sector in (data['customSectors'] as List? ?? [])) {
      await SectorService.addSector(sector as String);
    }
    final sectorAssignments = (data['sectorAssignments'] as Map?) ?? {};
    for (final entry in sectorAssignments.entries) {
      await SectorService.assignSector(entry.key as String, entry.value as String);
    }

    final manualPrices = (data['manualPrices'] as Map?) ?? {};
    for (final entry in manualPrices.entries) {
      await ManualPriceService.set(entry.key as String, (entry.value as num).toDouble());
    }

    final rateHistory = (data['currencyRateHistory'] as Map?) ?? {};
    for (final entry in rateHistory.entries) {
      final currency = entry.key as String;
      for (final point in (entry.value as List)) {
        final map = point as Map<String, dynamic>;
        await CurrencyService.setRateAt(
          currency,
          DateTime.parse(map['date']),
          (map['rate'] as num).toDouble(),
        );
      }
    }

    return count;
  }
}
