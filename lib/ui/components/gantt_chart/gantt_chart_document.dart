import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:booklet/ui/components/component_state.dart';

enum GanttChartType {
  standard('Standard Gantt'),
  tracking('Tracking Gantt');

  const GanttChartType(this.label);
  final String label;
}

enum GanttScale {
  auto('Auto'),
  day('Days'),
  week('Weeks'),
  month('Months');

  const GanttScale(this.label);
  final String label;
}

String ganttDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime parseGanttDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Use dates in YYYY-MM-DD format.');
  }
  final parts = value.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year < 1 || date.year > 9999 || ganttDate(date) != value) {
    throw const FormatException('Enter a valid calendar date.');
  }
  return date;
}

class GanttTask {
  GanttTask({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.progress = 0,
    this.baselineStart,
    this.baselineEnd,
    List<String> dependencies = const [],
  }) : dependencies = List.unmodifiable(dependencies);
  final String id, title;
  final DateTime start, end;
  final DateTime? baselineStart, baselineEnd;
  bool get hasBaseline => baselineStart != null && baselineEnd != null;
  final double progress;
  final List<String> dependencies;
  int get durationDays => end.difference(start).inDays + 1;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': ganttDate(start),
    'end': ganttDate(end),
    'progress': progress,
    'dependencies': List.of(dependencies),
    if (hasBaseline) 'baselineStart': ganttDate(baselineStart!),
    if (hasBaseline) 'baselineEnd': ganttDate(baselineEnd!),
  };
}

class GanttDocument {
  GanttDocument._(this.title, this.scale, this.type, List<GanttTask> tasks)
    : tasks = List.unmodifiable(tasks);
  final String title;
  final GanttScale scale;
  final GanttChartType type;
  final List<GanttTask> tasks;
  DateTime get start => tasks
      .expand(
        (t) => [
          t.start,
          if (type == GanttChartType.tracking && t.hasBaseline)
            t.baselineStart!,
        ],
      )
      .reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get end => tasks
      .expand(
        (t) => [
          t.end,
          if (type == GanttChartType.tracking && t.hasBaseline) t.baselineEnd!,
        ],
      )
      .reduce((a, b) => a.isAfter(b) ? a : b);
  int get durationDays => end.difference(start).inDays + 1;

  /// Finish-to-start links use inclusive task end dates. Conflicts are shown,
  /// rather than silently moving the user's dates.
  List<String> get warnings {
    final byId = {for (final t in tasks) t.id: t};
    return [
      for (final task in tasks)
        for (final id in task.dependencies)
          if (!task.start.isAfter(byId[id]!.end))
            '${task.title} starts before ${byId[id]!.title} has finished.',
    ];
  }

  factory GanttDocument.fromJson(Map<String, dynamic> json) {
    final title = json['title'] ?? '';
    if (title is! String) {
      throw const FormatException('Chart title must be text.');
    }
    final scale = GanttScale.values
        .where((s) => s.name == (json['timelineScale'] ?? 'auto'))
        .firstOrNull;
    if (scale == null) {
      throw const FormatException(
        'Choose auto, day, week, or month for timelineScale.',
      );
    }
    final type = GanttChartType.values
        .where((t) => t.name == (json['chartType'] ?? 'standard'))
        .firstOrNull;
    if (type == null) {
      throw const FormatException('Choose standard or tracking for chartType.');
    }
    final raw = json['tasks'];
    if (raw is! List || raw.isEmpty || raw.length > 100) {
      throw const FormatException('Include between 1 and 100 tasks.');
    }
    final tasks = <GanttTask>[];
    final ids = <String>{};
    for (var i = 0; i < raw.length; i++) {
      final task = raw[i];
      if (task is! Map ||
          task['id'] is! String ||
          (task['id'] as String).trim().isEmpty ||
          task['title'] is! String ||
          (task['title'] as String).trim().isEmpty) {
        throw FormatException('Task ${i + 1} needs an ID and a task name.');
      }
      final id = task['id'] as String;
      if (!ids.add(id)) throw const FormatException('Task IDs must be unique.');
      DateTime start, end;
      try {
        start = parseGanttDate(task['start']);
        end = parseGanttDate(task['end']);
      } on FormatException catch (e) {
        throw FormatException('Task ${i + 1}: ${e.message}');
      }
      if (end.isBefore(start)) {
        throw FormatException(
          'Task ${i + 1}: end date must be on or after start date.',
        );
      }
      DateTime? baselineStart, baselineEnd;
      if (task.containsKey('baselineStart') ||
          task.containsKey('baselineEnd')) {
        try {
          baselineStart = parseGanttDate(task['baselineStart']);
          baselineEnd = parseGanttDate(task['baselineEnd']);
        } on FormatException catch (e) {
          throw FormatException(
            'Task ${i + 1} baseline: ${e.message} Provide both baseline dates or omit both.',
          );
        }
        if (baselineEnd.isBefore(baselineStart)) {
          throw FormatException(
            'Task ${i + 1}: baseline end must be on or after baseline start.',
          );
        }
      }
      final progress = task.containsKey('progress') ? task['progress'] : 0;
      if (progress is! num ||
          !progress.isFinite ||
          progress < 0 ||
          progress > 100) {
        throw FormatException(
          'Task ${i + 1}: progress must be between 0 and 100.',
        );
      }
      final dependencies = task.containsKey('dependencies')
          ? task['dependencies']
          : [];
      if (dependencies is! List ||
          !dependencies.every((d) => d is String) ||
          dependencies.toSet().length != dependencies.length) {
        throw FormatException(
          'Task ${i + 1}: dependencies must be unique task IDs.',
        );
      }
      tasks.add(
        GanttTask(
          id: id,
          title: task['title'] as String,
          start: start,
          end: end,
          progress: progress.toDouble(),
          baselineStart: baselineStart,
          baselineEnd: baselineEnd,
          dependencies: dependencies.cast<String>(),
        ),
      );
    }
    final byId = {for (final t in tasks) t.id: t};
    final visiting = <String>{}, visited = <String>{};
    void visit(String id) {
      if (visited.contains(id)) return;
      if (!visiting.add(id)) {
        throw const FormatException('Dependencies cannot form a circle.');
      }
      for (final dep in byId[id]!.dependencies) {
        if (!byId.containsKey(dep)) {
          throw FormatException('Unknown dependency "$dep".');
        }
        if (dep == id) {
          throw const FormatException('A task cannot depend on itself.');
        }
        visit(dep);
      }
      visiting.remove(id);
      visited.add(id);
    }

    for (final id in byId.keys) {
      visit(id);
    }
    return GanttDocument._(title, scale, type, tasks);
  }
  Map<String, dynamic> toJson() => {
    'title': title,
    'timelineScale': scale.name,
    'chartType': type.name,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };
}

class GanttChartState extends ComponentState {
  GanttChartState() {
    final today = DateTime.now();
    final start = DateTime.utc(today.year, today.month, today.day);
    _document = GanttDocument.fromJson({
      'title': 'Writing project',
      'tasks': [
        {
          'id': 'plan',
          'title': 'Plan',
          'start': ganttDate(start),
          'end': ganttDate(start.add(const Duration(days: 1))),
          'progress': 100,
        },
        {
          'id': 'write',
          'title': 'Write',
          'start': ganttDate(start.add(const Duration(days: 2))),
          'end': ganttDate(start.add(const Duration(days: 6))),
          'progress': 40,
          'dependencies': ['plan'],
        },
        {
          'id': 'review',
          'title': 'Review',
          'start': ganttDate(start.add(const Duration(days: 7))),
          'end': ganttDate(start.add(const Duration(days: 9))),
          'dependencies': ['write'],
        },
      ],
    });
  }
  late GanttDocument _document;
  GanttDocument get document => _document;
  Map<String, dynamic> toJson() => _document.toJson();
  void restore(Map<String, dynamic> json) {
    final next = GanttDocument.fromJson(json);
    _document = next;
    notifyListeners();
  }

  @override
  Object get output => toJson();
}

List<DateTime> ganttTimelineTicks(GanttDocument document) {
  final start = document.start,
      end = document.end,
      days = document.durationDays;
  final scale = document.scale == GanttScale.auto
      ? (days <= 21
            ? GanttScale.day
            : days <= 120
            ? GanttScale.week
            : GanttScale.month)
      : document.scale;
  if (scale == GanttScale.month) {
    final months = (end.year - start.year) * 12 + end.month - start.month;
    final step = math.max(1, (months / 20).ceil());
    return [
      start,
      for (var i = step; i <= months; i += step)
        DateTime.utc(start.year, start.month + i),
    ];
  }
  final unit = scale == GanttScale.week ? 7 : 1;
  final step = math.max(unit, (days / 24 / unit).ceil() * unit);
  return [for (var i = 0; i < days; i += step) start.add(Duration(days: i))];
}

const ganttColors = [
  Colors.blue,
  Colors.teal,
  Colors.deepOrange,
  Colors.purple,
  Colors.indigo,
];

class GanttChartPreview extends StatelessWidget {
  const GanttChartPreview({super.key, required this.state});
  final GanttChartState state;
  @override
  Widget build(BuildContext context) {
    final document = state.document;
    final warnings = document.warnings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (document.title.isNotEmpty)
          Text(
            document.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        SizedBox(
          height:
              74 +
              document.tasks.length *
                  (document.type == GanttChartType.tracking ? 46.0 : 34.0),
          width: double.infinity,
          child: CustomPaint(
            painter: _GanttPainter(
              document,
              Theme.of(context).colorScheme,
              Theme.of(context).textTheme.bodySmall?.fontFamily,
            ),
          ),
        ),
        Text(
          '${ganttDate(document.start)} – ${ganttDate(document.end)} · End dates included · Darker bars show progress',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (document.type == GanttChartType.tracking) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              children: [
                const Text('Colored bars: current schedule'),
                Text(
                  'Gray bars: baseline',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!document.tasks.any((t) => t.hasBaseline))
            const Text(
              'No baseline yet. Use Capture baseline in Tasks to save the current plan, then adjust task dates to compare.',
              textAlign: TextAlign.center,
            ),
        ],
        if (warnings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${warnings.take(3).join('\n')}${warnings.length > 3 ? '\n…and ${warnings.length - 3} more scheduling conflicts.' : ''}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

class _GanttPainter extends CustomPainter {
  _GanttPainter(this.document, this.colors, this.fontFamily);
  final GanttDocument document;
  final ColorScheme colors;
  final String? fontFamily;
  @override
  void paint(Canvas canvas, Size size) {
    final tracking = document.type == GanttChartType.tracking;
    final rowHeight = tracking ? 46.0 : 34.0;
    final labelWidth = math.min(180.0, size.width * .32);
    final plot = Rect.fromLTWH(
      labelWidth,
      48,
      math.max(1, size.width - labelWidth - 16),
      document.tasks.length * rowHeight,
    );
    final paint = Paint();
    double x(DateTime date) =>
        plot.left +
        date.difference(document.start).inDays /
            document.durationDays *
            plot.width;
    double rowY(int i) => plot.top + i * rowHeight;
    void text(
      String value,
      Offset at,
      double width, {
      Color? color,
      double fontSize = 11,
    }) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color ?? colors.onSurface,
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(1, math.min(width, size.width - at.dx)));
      text.paint(canvas, at);
      text.dispose();
    }

    for (var i = 0; i < document.tasks.length; i++) {
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(0, rowY(i), size.width, rowHeight),
          paint..color = colors.surfaceContainerHighest.withValues(alpha: .35),
        );
      }
      canvas.drawLine(
        Offset(0, rowY(i) + rowHeight),
        Offset(size.width, rowY(i) + rowHeight),
        paint
          ..color = colors.outlineVariant
          ..strokeWidth = .5,
      );
      text(document.tasks[i].title, Offset(6, rowY(i) + 10), labelWidth - 14);
    }
    text(
      'Task',
      const Offset(6, 27),
      labelWidth - 14,
      color: colors.onSurfaceVariant,
    );
    final ticks = ganttTimelineTicks(document);
    final labelEvery = math.max(1, (ticks.length * 68 / plot.width).ceil());
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    for (var i = 0; i < ticks.length; i++) {
      final tick = ticks[i];
      canvas.drawLine(
        Offset(x(tick), plot.top),
        Offset(x(tick), plot.bottom),
        paint
          ..color = colors.outlineVariant
          ..strokeWidth = .5,
      );
      if (i % labelEvery == 0) {
        text(
          document.durationDays > 365
              ? '${months[tick.month - 1]} ${tick.year}'
              : '${months[tick.month - 1]} ${tick.day}',
          Offset(x(tick) + 3, 27),
          65,
          color: colors.onSurfaceVariant,
          fontSize: 10,
        );
      }
    }
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    if (!today.isBefore(document.start) && !today.isAfter(document.end)) {
      for (var y = plot.top; y < plot.bottom; y += 6) {
        canvas.drawLine(
          Offset(x(today), y),
          Offset(x(today), math.min(y + 3, plot.bottom)),
          paint
            ..color = colors.error
            ..strokeWidth = 1,
        );
      }
      text(
        'Today',
        Offset(x(today) + 2, 8),
        60,
        color: colors.error,
        fontSize: 10,
      );
    }
    final byId = {
      for (var i = 0; i < document.tasks.length; i++) document.tasks[i].id: i,
    };
    canvas.save();
    canvas.clipRect(plot);
    for (var i = 0; i < document.tasks.length; i++) {
      final task = document.tasks[i];
      for (final id in task.dependencies) {
        final predecessor = document.tasks[byId[id]!];
        final from = Offset(
          x(predecessor.end.add(const Duration(days: 1))),
          rowY(byId[id]!) + 17,
        );
        final to = Offset(x(task.start), rowY(i) + 17);
        final bendY = rowY(i) + 3;
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(from.dx + 7, from.dy)
          ..lineTo(from.dx + 7, bendY)
          ..lineTo(to.dx - 7, bendY)
          ..lineTo(to.dx - 7, to.dy)
          ..lineTo(to.dx, to.dy);
        final color = task.start.isAfter(predecessor.end)
            ? colors.onSurfaceVariant
            : colors.error;
        canvas.drawPath(
          path,
          paint
            ..color = color
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(to.dx - 4, to.dy - 3)
            ..lineTo(to.dx, to.dy)
            ..lineTo(to.dx - 4, to.dy + 3),
          paint,
        );
        paint.style = PaintingStyle.fill;
      }
    }
    for (var i = 0; i < document.tasks.length; i++) {
      final task = document.tasks[i];
      final rect = Rect.fromLTRB(
        x(task.start),
        rowY(i) + 8,
        x(task.end.add(const Duration(days: 1))),
        rowY(i) + 26,
      );
      if (tracking && task.hasBaseline) {
        final baseline = Rect.fromLTRB(
          x(task.baselineStart!),
          rowY(i) + 32,
          x(task.baselineEnd!.add(const Duration(days: 1))),
          rowY(i) + 38,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(baseline, const Radius.circular(2)),
          paint..color = colors.onSurfaceVariant.withValues(alpha: .65),
        );
      }
      final color = ganttColors[i % ganttColors.length];
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint..color = color.withValues(alpha: .25),
      );
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)));
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width * task.progress / 100,
          rect.height,
        ),
        paint..color = color,
      );
      canvas.restore();
      if (rect.width > 40) {
        text(
          '${task.progress.toStringAsFixed(0)}%',
          Offset(rect.left + 5, rect.top + 2),
          rect.width - 7,
          color: colors.onSurface,
          fontSize: 10,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GanttPainter oldDelegate) =>
      document != oldDelegate.document ||
      colors != oldDelegate.colors ||
      fontFamily != oldDelegate.fontFamily;
}
