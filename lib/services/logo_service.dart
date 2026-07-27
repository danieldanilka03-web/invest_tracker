import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
    final ext = sourceFile.path.split('.').last;
    await setLogoBytes(ticker, await sourceFile.readAsBytes(), ext);
  }

  /// То же самое, но из уже готовых байтов — используется при импорте
  /// бэкапа, где иконка хранится встроенной в JSON (base64), без отдельного
  /// файла на диске.
  static Future<void> setLogoBytes(String ticker, List<int> bytes, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final logosDir = Directory('${dir.path}/logos');
    if (!await logosDir.exists()) {
      await logosDir.create(recursive: true);
    }
    final cleanExt = ext.startsWith('.') ? ext : '.$ext';
    final destPath = '${logosDir.path}/${ticker.toUpperCase()}$cleanExt';

    // удаляем старый логотип этой бумаги, если был другого расширения
    final old = _box.get(ticker.toUpperCase());
    if (old != null && old != destPath && File(old).existsSync()) {
      await FileImage(File(old)).evict();
      await File(old).delete();
    }

    await File(destPath).writeAsBytes(bytes);
    // Flutter кэширует декодированную картинку по пути файла — раз путь у нас
    // всегда один и тот же для этого тикера (перезаписываем), без явного
    // сброса кэша старая картинка так и оставалась бы видна до перезапуска
    // приложения. Сбрасываем кэш именно для этого файла, чтобы новая картинка
    // отрисовалась сразу же везде, где показывается TickerAvatar.
    await FileImage(File(destPath)).evict();
    await _box.put(ticker.toUpperCase(), destPath);
    version.value++;
  }

  static Future<void> removeLogo(String ticker) async {
    final path = _box.get(ticker.toUpperCase());
    if (path != null) {
      await FileImage(File(path)).evict();
      if (File(path).existsSync()) {
        await File(path).delete();
      }
    }
    await _box.delete(ticker.toUpperCase());
    version.value++;
  }

  /// Все текущие логотипы — тикер -> абсолютный путь к файлу на диске
  /// (только существующие файлы). Используется для бэкапа.
  static Map<String, String> get allPaths {
    final map = <String, String>{};
    for (final key in _box.keys) {
      final ticker = key as String;
      final path = getPath(ticker);
      if (path != null) map[ticker] = path;
    }
    return map;
  }
}
