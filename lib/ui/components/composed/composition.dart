import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Versioned, portable layout tree. Percentages are relative weights on the
/// parent's main axis. Height is a minimum; content can grow beyond its share.
class CompositionNode {
  CompositionNode(
    this.kind, {
    String? id,
    this.children = const [],
    this.percent = 100,
    double padding = 8,
    double? horizontalPadding,
    double? verticalPadding,
    this.spacing = 8,
    this.height = 320,
    this.alignment = 'start',
    this.focusBar = false,
  }) : id = id ?? const Uuid().v4(),
       horizontalPadding = horizontalPadding ?? padding,
       verticalPadding = verticalPadding ?? padding;
  final String id;
  final String kind;
  List<CompositionNode> children;
  double percent, horizontalPadding, verticalPadding, spacing;

  /// Minimum composition height. The JSON key stays compatible with drafts.
  double height;
  String alignment;
  bool focusBar;
  bool get isLayout => kind == 'row' || kind == 'column';
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'percent': percent,
    'horizontalPadding': horizontalPadding,
    'verticalPadding': verticalPadding,
    'spacing': spacing,
    'height': height,
    'alignment': alignment,
    'focusBar': focusBar,
    'children': children.map((e) => e.toJson()).toList(),
  };
  factory CompositionNode.fromJson(Map<String, dynamic> json) =>
      CompositionNode(
        json['kind'] as String,
        id: json['id'] as String?,
        children: (json['children'] as List? ?? [])
            .map(
              (e) =>
                  CompositionNode.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        percent: ((json['percent'] as num?)?.toDouble() ?? 100).clamp(1, 100),
        horizontalPadding:
            ((json['horizontalPadding'] as num? ?? json['padding'] as num?)
                        ?.toDouble() ??
                    8)
                .clamp(0, 64),
        verticalPadding:
            ((json['verticalPadding'] as num? ?? json['padding'] as num?)
                        ?.toDouble() ??
                    8)
                .clamp(0, 64),
        spacing: ((json['spacing'] as num?)?.toDouble() ?? 8).clamp(0, 64),
        height: ((json['height'] as num?)?.toDouble() ?? 320).clamp(120, 1200),
        alignment: json['alignment'] as String? ?? 'start',
        focusBar: json['focusBar'] == true,
      );
}

class CompositionTemplate {
  CompositionTemplate(
    this.id,
    this.name,
    this.root, {
    this.sourceDocumentId,
    this.sourcePersonalId,
  });
  final String? sourcePersonalId;
  final String? sourceDocumentId;
  final String id, name;
  final CompositionNode root;
  String get key => 'composed:$id';
  Map<String, dynamic> toJson() => {
    'version': 1,
    if (sourceDocumentId != null) 'sourceDocumentId': sourceDocumentId,
    if (sourcePersonalId != null) 'sourcePersonalId': sourcePersonalId,
    'id': id,
    'name': name,
    'root': root.toJson(),
  };
  factory CompositionTemplate.fromJson(Map<String, dynamic> json) =>
      CompositionTemplate(
        json['id'] as String,
        json['name'] as String,
        CompositionNode.fromJson(
          Map<String, dynamic>.from(json['root'] as Map),
        ),
        sourceDocumentId: json['sourceDocumentId'] as String?,
        sourcePersonalId: json['sourcePersonalId'] as String?,
      );
}

class CompositionLibrary {
  // Document definitions are session-only and never written to preferences.
  static final documentTemplates = <CompositionTemplate>[];

  static CompositionTemplate registerDocument(
    CompositionTemplate template, {
    bool fromDocument = false,
  }) {
    final identity = jsonEncode({
      'name': template.name,
      'root': template.root.toJson(),
    });
    // A document reference must remain stable when its source layout changes.
    final id = template.id.startsWith('document:')
        ? template.id
        : 'document:${const Uuid().v5(Namespace.url.value, identity)}';
    for (final existing in documentTemplates) {
      if (existing.id == id) return find(id)!;
    }
    final copy = CompositionTemplate(
      id,
      template.name,
      CompositionNode.fromJson(template.root.toJson()),
      sourcePersonalId:
          template.sourcePersonalId ??
          (!fromDocument && !template.id.startsWith('document:')
              ? template.id
              : null),
    );
    documentTemplates.add(copy);
    return find(id)!;
  }

  static CompositionTemplate? personalCopyOf(CompositionTemplate template) {
    final root = jsonEncode(template.root.toJson());
    for (final personal in templates) {
      if (personal.id == template.sourcePersonalId ||
          personal.sourceDocumentId == template.id ||
          personal.root.id == template.root.id ||
          (personal.name == template.name &&
              jsonEncode(personal.root.toJson()) == root)) {
        return personal;
      }
    }
    return null;
  }

  static Future<CompositionTemplate> addToPersonal(
    CompositionTemplate template,
  ) async {
    final existing = personalCopyOf(template);
    if (existing != null) return existing;
    final copy = CompositionTemplate(
      const Uuid().v4(),
      template.name,
      CompositionNode.fromJson(template.root.toJson()),
      sourceDocumentId: template.id,
    );
    await save(copy);
    return copy;
  }

  static final changes = ValueNotifier<int>(0);

  static CompositionTemplate? find(String id) {
    for (final personal in templates) {
      if (personal.id == id) return personal;
    }
    for (final document in documentTemplates) {
      if (document.id != id) continue;
      final personal = personalCopyOf(document);
      if (personal == null) return document;
      return CompositionTemplate(
        document.id,
        personal.name,
        CompositionNode.fromJson(personal.root.toJson()),
        sourcePersonalId: personal.id,
      );
    }
    return null;
  }

  static CompositionTemplate resolve(
    String id, {
    Map<String, dynamic>? legacy,
  }) => CompositionTemplate.fromJson(
    find(id)?.toJson() ??
        legacy ??
        CompositionTemplate(
          id,
          'Unavailable composition',
          CompositionNode('column'),
        ).toJson(),
  );

  static final templates = <CompositionTemplate>[];
  static const storageKey = 'composed_components_v1';
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final loaded = <CompositionTemplate>[];
    if (raw != null) {
      for (final entry in jsonDecode(raw) as List) {
        loaded.add(
          CompositionTemplate.fromJson(Map<String, dynamic>.from(entry as Map)),
        );
      }
    }
    // Persist generated IDs once when upgrading early templates, so content
    // references remain stable across future application launches.
    if (raw != null) {
      final upgraded = jsonEncode(loaded.map((e) => e.toJson()).toList());
      if (upgraded != raw) await prefs.setString(storageKey, upgraded);
    }
    templates
      ..clear()
      ..addAll(loaded);
    changes.value++;
  }

  static Future<void> save(CompositionTemplate template) async {
    if (template.id.startsWith('document:')) {
      throw StateError(
        'Document components are read-only. Add a personal copy first.',
      );
    }
    final next = [...templates.where((e) => e.id != template.id), template];
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      storageKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    )) {
      throw StateError('Could not save composed components');
    }
    templates
      ..clear()
      ..addAll(next);
    changes.value++;
  }
}
