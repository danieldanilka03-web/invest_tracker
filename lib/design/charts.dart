import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

// =============================================================================
// СПАРКЛАЙН
// =============================================================================

/// Плавная линия стоимости с градиентной заливкой, неоновым свечением и
/// «прокруткой» пальцем: при ведении по графику подсвечивается конкретная
/// точка, показывается её значение и даётся лёгкая тактильная отдача.
///
/// Написан на CustomPaint вместо готовой библиотеки — так линия рисуется
/// анимированно (прочерчивается слева направо при появлении) и свечение
/// выглядит именно так, как задумано.
class Sparkline extends StatefulWidget {
  final List<double> values;
  final Color color;
  final double height;
  final bool fill;
  final bool interactive;
  final String Function(int index, double value)? tooltipBuilder;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 140,
    this.fill = true,
    this.interactive = true,
    this.tooltipBuilder,
  });

  @override
  State<Sparkline> createState() => _SparklineState();
}

class _SparklineState extends State<Sparkline> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppDuration.chart);
  int? _touch;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant Sparkline old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _updateTouch(double dx, double width) {
    final n = widget.values.length;
    if (n < 2) return;
    final idx = ((dx / width) * (n - 1)).round().clamp(0, n - 1);
    if (idx != _touch) {
      setState(() => _touch = idx);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    if (values.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            'Мало данных для графика',
            style: TextStyle(fontSize: 12, color: context.dim),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final touchedX = _touch == null ? 0.0 : (_touch! / (values.length - 1)) * w;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.interactive ? (d) => _updateTouch(d.localPosition.dx, w) : null,
          onHorizontalDragUpdate: widget.interactive ? (d) => _updateTouch(d.localPosition.dx, w) : null,
          onHorizontalDragEnd: widget.interactive ? (_) => setState(() => _touch = null) : null,
          onHorizontalDragCancel: widget.interactive ? () => setState(() => _touch = null) : null,
          onTapDown: widget.interactive ? (d) => _updateTouch(d.localPosition.dx, w) : null,
          onTapUp: widget.interactive ? (_) => setState(() => _touch = null) : null,
          onTapCancel: widget.interactive ? () => setState(() => _touch = null) : null,
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => CustomPaint(
                      painter: _SparklinePainter(
                        values: values,
                        color: widget.color,
                        progress: Curves.easeOutCubic.transform(_c.value),
                        fill: widget.fill,
                        touchIndex: _touch,
                      ),
                    ),
                  ),
                ),
                if (_touch != null)
                  Positioned(
                    left: (touchedX - 50).clamp(0.0, math.max(0.0, w - 100)),
                    top: 0,
                    child: _Tooltip(
                      text: widget.tooltipBuilder?.call(_touch!, values[_touch!]) ??
                          values[_touch!].toStringAsFixed(0),
                      color: widget.color,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Tooltip extends StatelessWidget {
  final String text;
  final Color color;

  const _Tooltip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkSurfaceTop : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.45)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.22), blurRadius: 14)],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.25),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double progress;
  final bool fill;
  final int? touchIndex;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.progress,
    required this.fill,
    this.touchIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    double minV = values.first;
    double maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    // Плоская линия (все значения равны) не должна схлопываться в ноль
    // высоты — раздвигаем диапазон искусственно и рисуем её посередине.
    if ((maxV - minV).abs() < 1e-9) {
      minV -= 1;
      maxV += 1;
    }

    const padTop = 14.0;
    const padBottom = 8.0;
    final usable = size.height - padTop - padBottom;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final norm = (values[i] - minV) / (maxV - minV);
      points.add(Offset(x, padTop + (1 - norm) * usable));
    }

    // Сглаживание через квадратичные кривые по серединам отрезков — линия
    // получается мягкой, но не «уезжает» за пределы реальных значений, как
    // это делают кубические сплайны на резких скачках.
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      line.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    line.lineTo(points.last.dx, points.last.dy);

    // Частичный путь для анимации «прочерчивания»
    final drawn = Path();
    for (final metric in line.computeMetrics()) {
      drawn.addPath(metric.extractPath(0, metric.length * progress), Offset.zero);
    }

    if (fill) {
      final cutX = size.width * progress;
      final area = Path.from(drawn)
        ..lineTo(cutX, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.32), color.withOpacity(0.02)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(area, areaPaint);
    }

    // Свечение под линией
    final glow = Paint()
      ..color = color.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.drawPath(drawn, glow);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawn, stroke);

    // Точка на конце линии — «где мы сейчас»
    if (progress > 0.98) {
      final last = points.last;
      canvas.drawCircle(last, 8, Paint()..color = color.withOpacity(0.22));
      canvas.drawCircle(last, 4, Paint()..color = color);
      canvas.drawCircle(last, 1.8, Paint()..color = Colors.white);
    }

    // Подсветка точки под пальцем
    if (touchIndex != null && touchIndex! < points.length) {
      final p = points[touchIndex!];
      final guide = Paint()
        ..color = color.withOpacity(0.35)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(p.dx, 0), Offset(p.dx, size.height), guide);
      canvas.drawCircle(p, 9, Paint()..color = color.withOpacity(0.25));
      canvas.drawCircle(p, 5, Paint()..color = color);
      canvas.drawCircle(p, 2.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.progress != progress ||
      old.touchIndex != touchIndex ||
      old.color != color ||
      old.values.length != values.length;
}

// =============================================================================
// КОЛЬЦЕВАЯ ДИАГРАММА
// =============================================================================

/// Пончик с анимированным раскрытием, выделением доли по тапу (и по клику
/// на легенду) и живым центром: пока ничего не выбрано — там общая сумма,
/// при выборе — название доли и её процент.
class DonutChart extends StatefulWidget {
  final Map<String, double> data;
  final double size;
  final String Function(double) valueFormatter;
  final String centerLabel;

  const DonutChart({
    super.key,
    required this.data,
    required this.valueFormatter,
    this.size = 210,
    this.centerLabel = 'Всего',
  });

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, duration: AppDuration.chart)..forward();
  late final AnimationController _select =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  int _selected = -1;

  @override
  void dispose() {
    _enter.dispose();
    _select.dispose();
    super.dispose();
  }

  void _select_(int i) {
    setState(() => _selected = _selected == i ? -1 : i);
    _select.forward(from: 0);
    HapticFeedback.selectionClick();
  }

  void _handleTap(Offset local) {
    final c = Offset(widget.size / 2, widget.size / 2);
    final v = local - c;
    final dist = v.distance;
    final outer = widget.size / 2;
    if (dist < outer * 0.42 || dist > outer) {
      if (_selected != -1) _select_(_selected);
      return;
    }
    double angle = math.atan2(v.dy, v.dx) + math.pi / 2; // отсчёт от «12 часов»
    if (angle < 0) angle += 2 * math.pi;

    final entries = widget.data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) return;
    double acc = 0;
    for (int i = 0; i < entries.length; i++) {
      final sweep = (entries[i].value / total) * 2 * math.pi;
      if (angle >= acc && angle < acc + sweep) {
        _select_(i);
        return;
      }
      acc += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (s, e) => s + e.value);
    final sel = _selected >= 0 && _selected < entries.length ? entries[_selected] : null;

    return Column(
      children: [
        SizedBox(
          height: widget.size,
          width: widget.size,
          child: GestureDetector(
            onTapDown: (d) => _handleTap(d.localPosition),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_enter, _select]),
                  builder: (context, _) => CustomPaint(
                    size: Size.square(widget.size),
                    painter: _DonutPainter(
                      values: entries.map((e) => e.value).toList(),
                      progress: Curves.easeOutCubic.transform(_enter.value),
                      selected: _selected,
                      selectProgress: Curves.easeOutBack.transform(_select.value.clamp(0.0, 1.0)),
                      trackColor: context.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.size * 0.22),
                  child: AnimatedSwitcher(
                    duration: AppDuration.fast,
                    child: Column(
                      key: ValueKey(_selected),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sel?.key ?? widget.centerLabel,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.dim),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.valueFormatter(sel?.value ?? total),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        if (sel != null && total > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${(sel.value / total * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.chartAt(_selected),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (int i = 0; i < entries.length; i++)
              GestureDetector(
                onTap: () => _select_(i),
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selected == i
                        ? AppColors.chartAt(i).withOpacity(0.18)
                        : (context.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _selected == i ? AppColors.chartAt(i) : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: AppColors.chartAt(i), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          entries[i].key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: _selected == i ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        total > 0 ? '${(entries[i].value / total * 100).toStringAsFixed(0)}%' : '0%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.dim),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final int selected;
  final double selectProgress;
  final Color trackColor;

  _DonutPainter({
    required this.values,
    required this.progress,
    required this.selected,
    required this.selectProgress,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (s, v) => s + v);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;
    final thickness = outer * 0.26;
    final baseRadius = outer - thickness / 2 - 6;

    canvas.drawCircle(
      center,
      baseRadius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );

    // Зазор между секторами постоянный в радианах и одинаковый для всех:
    // ровные промежутки читаются как единое кольцо, а разнобой сразу бросается
    // в глаза. Концы дуг прямые (butt) — скруглённые выступали за край дуги на
    // половину её толщины и съедали зазор тем сильнее, чем толще кольцо.
    const gap = 0.045;
    const minSweep = 0.02; // чтобы доля в полпроцента не исчезла совсем
    double start = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final full = (values[i] / total) * 2 * math.pi;
      if (full <= 0) continue;

      final isSel = i == selected;
      final radius = baseRadius + (isSel ? 5 * selectProgress : 0);
      final width = thickness + (isSel ? 6 * selectProgress : 0);
      final color = AppColors.chartAt(i);

      final from = start + gap / 2;
      final sweep = math.max(full - gap, minSweep) * progress;

      if (sweep > 0) {
        // Заливка — линейный градиент по всему кольцу, а не sweep-градиент по
        // сектору: у sweep-градиента отсчёт идёт от трёх часов, и на длинной
        // дуге он давал резкий стык там, где проходил через ноль.
        final shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppGradient.lighten(color, 0.12), color],
        ).createShader(Rect.fromCircle(center: center, radius: radius + width / 2));

        if (isSel) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            from,
            sweep,
            false,
            Paint()
              ..color = color.withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10),
          );
        }

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          from,
          sweep,
          false,
          Paint()
            ..shader = shader
            ..style = PaintingStyle.stroke
            ..strokeWidth = width,
        );
      }

      start += full;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.selectProgress != selectProgress ||
      old.values.length != values.length;
}

// =============================================================================
// СТОЛБЧАТАЯ ДИАГРАММА
// =============================================================================

/// Столбцы, вырастающие снизу вверх при появлении. Тап по столбцу
/// подсвечивает его и показывает точное значение над ним.
class BarsChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double height;
  final String Function(double) valueFormatter;

  const BarsChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    required this.valueFormatter,
    this.height = 190,
  });

  @override
  State<BarsChart> createState() => _BarsChartState();
}

class _BarsChartState extends State<BarsChart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppDuration.chart)..forward();
  int _selected = -1;

  @override
  void didUpdateWidget(covariant BarsChart old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: Text('Нет данных за период', style: TextStyle(fontSize: 12, color: context.dim))),
      );
    }

    final maxV = widget.values.reduce(math.max);

    return LayoutBuilder(
      builder: (context, constraints) {
        const minBarSlot = 54.0;
        final needed = widget.values.length * minBarSlot;
        final width = math.max(constraints.maxWidth, needed);
        final content = SizedBox(
          height: widget.height,
          width: width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < widget.values.length; i++)
                Expanded(
                  child: _Bar(
                    value: widget.values[i],
                    maxValue: maxV <= 0 ? 1 : maxV,
                    label: i < widget.labels.length ? widget.labels[i] : '',
                    color: widget.color,
                    animation: _c,
                    delay: i / (widget.values.length * 1.6),
                    selected: _selected == i,
                    valueText: widget.valueFormatter(widget.values[i]),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = _selected == i ? -1 : i);
                    },
                  ),
                ),
            ],
          ),
        );

        if (needed <= constraints.maxWidth) return content;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // открываемся сразу на самых свежих месяцах
          physics: const BouncingScrollPhysics(),
          child: content,
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double maxValue;
  final String label;
  final String valueText;
  final Color color;
  final Animation<double> animation;
  final double delay;
  final bool selected;
  final VoidCallback onTap;

  const _Bar({
    required this.value,
    required this.maxValue,
    required this.label,
    required this.valueText,
    required this.color,
    required this.animation,
    required this.delay,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          // Каждый столбец стартует чуть позже предыдущего — получается
          // «волна» роста слева направо.
          final raw = ((animation.value - delay) / (1 - delay)).clamp(0.0, 1.0);
          final t = Curves.easeOutCubic.transform(raw);
          final ratio = (value / maxValue).clamp(0.0, 1.0) * t;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedOpacity(
                  duration: AppDuration.fast,
                  opacity: selected ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      valueText,
                      maxLines: 1,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: ratio < 0.02 ? 0.02 : ratio,
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                          bottom: Radius.circular(3),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: selected
                              ? [AppGradient.lighten(color, 0.14), color]
                              : [color.withOpacity(0.85), color.withOpacity(0.32)],
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4))]
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? color : context.dim,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// КОЛЬЦО ПРОГРЕССА
// =============================================================================

/// Кольцо выполнения — используется в планах покупок: сколько уже куплено
/// из запланированного.
class ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final double thickness;
  final Color color;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 54,
    this.thickness = 5,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
      duration: AppDuration.slow,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: v,
            color: color,
            thickness: thickness,
            track: context.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double thickness;
  final Color track;

  _RingPainter({required this.progress, required this.color, required this.thickness, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - thickness / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness,
    );

    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = LinearGradient(
          colors: [color, AppGradient.lighten(color, 0.18)],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}

/// Горизонтальная полоса-индикатор доли (вес бумаги в портфеле, прогресс плана).
class MiniProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;

  const MiniProgressBar({super.key, required this.value, required this.color, this.height = 5});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(
            height: height,
            color: context.isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value.clamp(0.0, 1.0)),
            duration: AppDuration.slow,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height),
                  gradient: LinearGradient(colors: [color.withOpacity(0.6), color]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
