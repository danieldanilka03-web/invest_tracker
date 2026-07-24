import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Пользовательские логотипы ценных бумаг. Картинка копируется в постоянную
/// папку приложения на устройстве и путь к ней сохраняется в Hive.
/// Никакой загрузки в интернет — всё остаётся локально на телефоне.
class LogoService {
  static const boxName = 'ticker_logos';
  static late Box<String> _box;

  static final ValueNotifier<int> version = ValueNotifier(0);

  static Future<void> init() async {
    _box = await Hive.openBox<String>(boxName);
  }

  static String? getPath(String ticker) {
    final path = _box.get(ticker.toUpperCase());
    if (path == null) return null;
    if (!File(path).existsSync()) return null;
    return path;
  }

  static Future<void> setLogo(String ticker, File sourceFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final logosDir = Directory('${dir.path}/logos');
    if (!await logosDir.exists()) {
      await logosDir.create(recursive: true);
    }
    final ext = sourceFile.path.split('.').last;
    final destPath = '${logosDir.path}/${ticker.toUpperCase()}.$ext';

    // удаляем старый логотип этой бумаги, если был другого расширения
    final old = _box.get(ticker.toUpperCase());
    if (old != null && old != destPath && File(old).existsSync()) {
      await File(old).delete();
    }

    await sourceFile.copy(destPath);
    await _box.put(ticker.toUpperCase(), destPath);
    version.value++;
  }

  static Future<void> removeLogo(String ticker) async {
    final path = _box.get(ticker.toUpperCase());
    if (path != null && File(path).existsSync()) {
      await File(path).delete();
    }
    await _box.delete(ticker.toUpperCase());
    version.value++;
  }
}
