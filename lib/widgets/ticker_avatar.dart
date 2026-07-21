import 'package:flutter/material.dart';

/// Генерирует стабильный цвет по строке (тикеру), чтобы у одной и той же
/// бумаги всегда была одинаковая аватарка между запусками приложения.
class TickerAvatar extends StatelessWidget {
  final String ticker;
  final double size;

  const TickerAvatar({super.key, required this.ticker, this.size = 40});

  static const List<List<Color>> _palettes = [
    [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
    [Color(0xFF00B894), Color(0xFF55EFC4)],
    [Color(0xFFE17055), Color(0xFFFAB1A0)],
    [Color(0xFF0984E3), Color(0xFF74B9FF)],
    [Color(0xFFE84393), Color(0xFFFD79A8)],
    [Color(0xFFD63031), Color(0xFFFF7675)],
    [Color(0xFF00CEC9), Color(0xFF81ECEC)],
    [Color(0xFFFDCB6E), Color(0xFFFFEAA7)],
    [Color(0xFF6C5B7B), Color(0xFFC06C84)],
    [Color(0xFF2D3436), Color(0xFF636E72)],
  ];

  List<Color> get _gradient {
    final hash = ticker.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palettes[hash % _palettes.length];
  }

  String get _initials {
    if (ticker.isEmpty) return '?';
    // для длинных тикеров облигаций берём первые 2 буквы, иначе 2-3 значимых символа
    final clean = ticker.replaceAll(RegExp(r'[^A-Za-zА-Яа-я0-9]'), '');
    if (clean.isEmpty) return '?';
    return clean.length >= 2 ? clean.substring(0, 2).toUpperCase() : clean.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradient;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.34,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
