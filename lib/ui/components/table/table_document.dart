import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/application/page_settings_controller.dart';

class TableCellData {
  TableCellData({
    this.text = '',
    this.bold = false,
    this.italic = false,
    this.alignment = TextAlign.left,
    this.color,
  });
  String text;
  bool bold;
  bool italic;
  TextAlign alignment;
  int? color;
  Map<String, dynamic> toJson() => {
    'text': text,
    'bold': bold,
    'italic': italic,
    'alignment': alignment.name,
    'color': color,
  };
  factory TableCellData.fromJson(Map json) => TableCellData(
    text: json['text'] as String? ?? '',
    bold: json['bold'] == true,
    italic: json['italic'] == true,
    alignment: TextAlign.values.firstWhere(
      (v) => v.name == json['alignment'],
      orElse: () => TextAlign.left,
    ),
    color: json['color'] as int?,
  );
}

class TableComponentState extends ComponentState {
  List<List<TableCellData>> rows = List.generate(
    3,
    (_) => List.generate(3, (_) => TableCellData()),
  );
  bool header = true;
  bool borders = true;
  bool striped = false;
  double columnWidth = 160;
  int get columnCount => rows.first.length;
  List<double> _columnWidthPercentages = [100, 100, 100];
  double columnWidthPercentage(int column) => _columnWidthPercentages[column];
  double widthForColumn(int column) =>
      columnWidth * columnWidthPercentage(column) / 100;
  double get tableWidth => List.generate(
    columnCount,
    widthForColumn,
  ).fold(0, (sum, width) => sum + width);
  void setColumnWidthPercentage(int column, double percentage) {
    if (!percentage.isFinite) return;
    _columnWidthPercentages[column] = percentage.clamp(10, 300);
  }

  Map<String, dynamic> toJson() => {
    'rows': rows.map((r) => r.map((c) => c.toJson()).toList()).toList(),
    'header': header,
    'borders': borders,
    'striped': striped,
    'columnWidth': columnWidth,
    'columnWidthPercentages': List<double>.of(_columnWidthPercentages),
  };
  void restore(Map<String, dynamic> json) {
    final raw = json['rows'];
    if (raw is List &&
        raw.isNotEmpty &&
        raw.every((r) => r is List && r.isNotEmpty)) {
      final width = (raw.first as List).length;
      if (raw.every((r) => (r as List).length == width)) {
        rows = raw
            .map(
              (r) => (r as List)
                  .map((c) => TableCellData.fromJson(c as Map))
                  .toList(),
            )
            .toList();
      }
    }
    final percentages = json['columnWidthPercentages'];
    _columnWidthPercentages = List.generate(columnCount, (index) {
      final value = percentages is List && index < percentages.length
          ? percentages[index]
          : null;
      return value is num && value.isFinite
          ? value.toDouble().clamp(10, 300)
          : 100.0;
    });
    header = json['header'] != false;
    borders = json['borders'] != false;
    striped = json['striped'] == true;
    columnWidth = (json['columnWidth'] as num? ?? 160).toDouble().clamp(
      80,
      400,
    );
    notifyListeners();
  }

  TableComponentState clone() => TableComponentState()
    ..restore(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(toJson())) as Map),
    );
  void insertRow(int index) =>
      rows.insert(index, List.generate(columnCount, (_) => TableCellData()));
  void insertColumn(int index) {
    _columnWidthPercentages.insert(index, 100);
    for (final row in rows) {
      row.insert(index, TableCellData());
    }
  }

  void removeRow(int index) {
    if (rows.length > 1) rows.removeAt(index);
  }

  void removeColumn(int index) {
    if (columnCount > 1) {
      _columnWidthPercentages.removeAt(index);
      for (final row in rows) {
        row.removeAt(index);
      }
    }
  }

  @override
  Map<String, dynamic> get output => toJson();
}

class TablePreview extends StatelessWidget {
  const TablePreview({
    super.key,
    required this.state,
    this.onCell,
    this.pageSettings,
    this.selectedRow = -1,
    this.selectedColumn = -1,
  });
  final TableComponentState state;
  final PageSettingsController? pageSettings;
  final void Function(int, int)? onCell;
  final int selectedRow;
  final int selectedColumn;
  @override
  Widget build(BuildContext context) {
    final page = pageSettings;
    final colors = page == null
        ? Theme.of(context).colorScheme
        : ColorScheme.fromSeed(
            seedColor: page.styleColor,
            brightness: page.effectiveBrightness,
          );
    final textColor = page?.textColor ?? colors.onSurface;
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
      columnWidths: {
        for (var c = 0; c < state.columnCount; c++)
          c: FixedColumnWidth(state.widthForColumn(c)),
      },
      border: state.borders
          ? TableBorder.all(color: colors.outlineVariant)
          : null,
      children: [
        for (var r = 0; r < state.rows.length; r++)
          TableRow(
            children: [
              for (var c = 0; c < state.columnCount; c++)
                Builder(
                  builder: (context) {
                    final cell = state.rows[r][c];
                    return GestureDetector(
                      onTap: onCell == null ? null : () => onCell!(r, c),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cell.color != null
                              ? Color(cell.color!)
                              : state.header && r == 0
                              ? colors.primaryContainer
                              : state.striped && r.isOdd
                              ? colors.surfaceContainerLow
                              : null,
                          border: selectedRow == r && selectedColumn == c
                              ? Border.all(color: colors.primary, width: 2)
                              : null,
                        ),
                        child: Text(
                          cell.text.isEmpty && onCell != null ? ' ' : cell.text,
                          textAlign: cell.alignment,
                          style: TextStyle(
                            color: cell.color != null
                                ? (ThemeData.estimateBrightnessForColor(
                                            Color(cell.color!),
                                          ) ==
                                          Brightness.light
                                      ? Colors.black
                                      : Colors.white)
                                : state.header && r == 0
                                ? colors.onPrimaryContainer
                                : textColor,
                            fontFamily: page?.bodyFontFamily,
                            fontSize: page?.baseFontSize,
                            fontWeight: cell.bold || state.header && r == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontStyle: cell.italic
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// Keeps horizontal scrolling independent of the page/editor vertical scroller.
class TableScrollView extends StatefulWidget {
  const TableScrollView({
    super.key,
    required this.width,
    required this.child,
    this.scrollVertically = false,
  });
  final double width;
  final Widget child;
  final bool scrollVertically;
  @override
  State<TableScrollView> createState() => _TableScrollViewState();
}

class _TableScrollViewState extends State<TableScrollView> {
  final horizontal = ScrollController();
  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: horizontal,
    thumbVisibility: true,
    trackVisibility: true,
    scrollbarOrientation: ScrollbarOrientation.bottom,
    notificationPredicate: (notification) =>
        notification.metrics.axis == Axis.horizontal,
    child: SingleChildScrollView(
      controller: horizontal,
      primary: false,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: widget.width,
        child: widget.scrollVertically
            ? SingleChildScrollView(primary: false, child: widget.child)
            : widget.child,
      ),
    ),
  );
}
