import 'dart:convert';

import 'package:booklet/ui/components/focus_bar.dart';

import 'dart:math' as math;

import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';

import 'composition.dart';

class ComposedComponent extends Component implements ComponentFocusScope {
  ComposedComponent(this.id, CompositionTemplate template)
    : state = ComposedState(template);
  @override
  final String id;
  @override
  final ComposedState state;
  @override
  ComponentDef get def => _ComposedDef(state.template);
  @override
  bool get hasFocusedChild => state.leaves.values.any((box) => box.isFocused);

  @override
  void clearChildFocus() {
    for (final box in state.leaves.values) {
      box.isSelected = false;
      box.clearFocus();
    }
  }

  @override
  Widget buildUI({
    required PageSettingsController theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    Widget render(CompositionNode node, {double minHeight = 0}) {
      Widget child;
      if (node.isLayout) {
        final items = <Widget>[];
        final isRow = node.kind == 'row';
        final contentMinimum = math.max(
          0.0,
          minHeight - node.verticalPadding * 2,
        );
        final available = math.max(
          0.0,
          contentMinimum - node.spacing * math.max(0, node.children.length - 1),
        );
        final total = node.children.fold(
          0.0,
          (sum, child) => sum + child.percent,
        );
        for (final item in node.children) {
          if (items.isNotEmpty) {
            items.add(SizedBox(width: node.spacing, height: node.spacing));
          }
          final child = render(
            item,
            minHeight: isRow
                ? contentMinimum
                : available * item.percent / total,
          );
          items.add(
            isRow
                ? Expanded(flex: (item.percent * 100).round(), child: child)
                : child,
          );
        }
        final alignment = switch (node.alignment) {
          'center' => CrossAxisAlignment.center,
          'end' => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.start,
        };
        child = Flex(
          mainAxisSize: MainAxisSize.min,
          direction: node.kind == 'row' ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: alignment,
          children: items,
        );
      } else {
        final box = state.leaves[node]!;
        child = box.buildUI(
          theme: theme,
          isNested: true,
          onSelect: () {
            for (final sibling in state.leaves.values) {
              sibling.isSelected = false;
              if (sibling != box) sibling.clearFocus();
            }
            if (!theme.documentSettingsController.isReadOnly) {
              // Mark focus before selecting the outer box: EditorView checks
              // it synchronously to decide whether to claim page focus.
              box.requestFocus(markFocused: true);
            }
            onSelect();
          },
          onSelectRange: onSelect,
          onCreateBelow: (_) {},
          onBackspaceAtStart: () {},
          onMoveToAdjacentTextComponent: (_) {},
          onPasteText: (_) async => false,
        );
      }
      final content = Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: EdgeInsets.symmetric(
          horizontal: node.horizontalPadding,
          vertical: node.verticalPadding,
        ),
        child: child,
      );
      return node.focusBar
          ? FocusBar(color: theme.styleColor, child: content)
          : content;
    }

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        state.refreshStructure(notify: false);
        return state.template.name == 'Unavailable composition' &&
                CompositionLibrary.find(state.template.id) == null
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Composition structure unavailable. Restore the saved template to edit this content.',
                ),
              )
            : render(
                state.template.root,
                minHeight: state.template.root.height,
              );
      },
    );
  }
}

class ComposedState extends ComponentState {
  ComposedState(this.template) {
    _build();
    CompositionLibrary.changes.addListener(_refreshStructure);
  }
  CompositionTemplate template;
  Map<String, dynamic> _storedChildren = {};

  void _refreshStructure() => refreshStructure();

  void refreshStructure({bool notify = true}) {
    final latest = CompositionLibrary.find(template.id);
    if (latest != null &&
        jsonEncode(latest.toJson()) != jsonEncode(template.toJson())) {
      updateLayout(
        CompositionTemplate.fromJson(latest.toJson()),
        notify: notify,
      );
    }
  }

  final leaves = <CompositionNode, ComponentBox>{};
  void _build() {
    void visit(CompositionNode node) {
      if (node.isLayout) {
        for (final child in node.children) {
          visit(child);
        }
      } else {
        final box = ComponentBox(
          component: InbuiltComponents.prepareCompoent(
            const Uuid().v4(),
            node.kind,
          ),
        );
        leaves[node] = box;
        box.component.state.addListener(notifyListeners);
      }
    }

    visit(template.root);
  }

  /// Reconcile a live layout by node identity so scratch content and focus
  /// survive padding, spacing, nesting, and ordering changes.
  void updateLayout(CompositionTemplate next, {bool notify = true}) {
    _storedChildren = Map<String, dynamic>.from(toJson()['children'] as Map);
    final previous = {for (final entry in leaves.entries) entry.key.id: entry};
    leaves.clear();
    final removed = <ComponentBox>[];
    void visit(CompositionNode node) {
      if (node.isLayout) {
        for (final child in node.children) {
          visit(child);
        }
      } else {
        final old = previous.remove(node.id);
        final reusable = old != null && old.key.kind == node.kind;
        final box = reusable
            ? old.value
            : ComponentBox(
                component: InbuiltComponents.prepareCompoent(
                  const Uuid().v4(),
                  node.kind,
                ),
              );
        if (!reusable) {
          final saved = _storedChildren[node.id];
          if (saved is Map && saved['type'] == node.kind) {
            box.dispose();
            final restored = ComponentSnapshot.fromJson(
              Map<String, dynamic>.from(saved),
            ).instantiate();
            leaves[node] = restored;
            restored.component.state.addListener(notifyListeners);
            if (old != null) removed.add(old.value);
            return;
          }
          box.component.state.addListener(notifyListeners);
          if (old != null) removed.add(old.value);
        }
        leaves[node] = box;
      }
    }

    template = next;
    visit(next.root);
    removed.addAll(previous.values.map((entry) => entry.value));
    for (final box in removed) {
      box.component.state.removeListener(notifyListeners);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final box in removed) {
        box.dispose();
      }
    });
    if (notify) notifyListeners();
  }

  /// Instance persistence carries content and a reference, never layout/style.
  Map<String, dynamic> toJson() => {
    'templateId': template.id,
    'children': {
      ..._storedChildren,
      for (final entry in leaves.entries)
        entry.key.id: ComponentSnapshot.capture(entry.value).toJson(),
    },
  };

  void restore(Map<String, dynamic> json) {
    final raw = json['children'];
    if (raw is Map) {
      _storedChildren = Map<String, dynamic>.from(raw);
    } else if (raw is List) {
      // Read the initial draft's positional snapshots without writing layout.
      final legacy = json['template'];
      final old = legacy is Map
          ? CompositionTemplate.fromJson(Map<String, dynamic>.from(legacy))
          : template;
      final ids = <String>[];
      void visit(CompositionNode n) {
        if (n.isLayout) {
          for (final c in n.children) {
            visit(c);
          }
        } else {
          ids.add(n.id);
        }
      }

      visit(old.root);
      _storedChildren = {
        for (var i = 0; i < ids.length && i < raw.length; i++) ids[i]: raw[i],
      };
    }
    _clear();
    _build();
    _restoreStoredChildren();
  }

  void _restoreStoredChildren() {
    for (final node in leaves.keys.toList()) {
      final raw = _storedChildren[node.id];
      if (raw is! Map || raw['type'] != node.kind) continue;
      leaves[node]!.dispose();
      final box = ComponentSnapshot.fromJson(Map<String, dynamic>.from(raw))
          .instantiate();
      leaves[node] = box;
      box.component.state.addListener(notifyListeners);
    }
  }

  void _clear() {
    for (final box in leaves.values) {
      box.dispose();
    }
    leaves.clear();
  }

  @override
  Object get output =>
      leaves.values.map((box) => box.component.output).toList();
  @override
  void dispose() {
    CompositionLibrary.changes.removeListener(_refreshStructure);
    _clear();
    super.dispose();
  }
}

class _ComposedDef extends ComponentDef {
  _ComposedDef(this.template);
  final CompositionTemplate template;
  @override
  ComponentKind get kind => ComponentKind.composed;
  @override
  String get key => template.key;
  @override
  String get name => template.name;
  @override
  ComponentType get type => ComponentType.media;
}
