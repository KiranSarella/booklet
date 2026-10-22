import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/code_block_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/math_component.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:uuid/uuid.dart';

/// An immutable, self-contained copy of a component's content, independent of
/// any page/document. Used to implement copy/paste across pages and
/// documents: capture a snapshot while the source component is still alive,
/// then call [instantiate] any number of times to produce fresh components.
class ComponentSnapshot {
  ComponentSnapshot._({
    required this.typeKey,
    this.delta,
    this.extra = const {},
  });

  final String typeKey;
  final List<dynamic>? delta;
  final Map<String, dynamic> extra;

  factory ComponentSnapshot.capture(ComponentBox box) {
    final snapshot = _captureContent(box);
    if (!box.hasFocusBar) return snapshot;
    return ComponentSnapshot._(
      typeKey: snapshot.typeKey,
      delta: snapshot.delta,
      extra: {...snapshot.extra, 'focusBar': true},
    );
  }

  static ComponentSnapshot _captureContent(ComponentBox box) {
    final component = box.component;
    final state = component.state;

    if (state is QuoteComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        delta: state.quote.textDelta,
        extra: {'authorDelta': state.author.textDelta},
      );
    }
    if (state is ImageComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        extra: {
          'mediaPath': state.mediaPath,
          'imageSize': state.imageSize,
          'width': state.width,
          'height': state.height,
        },
      );
    }
    if (state is VideoComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        extra: {'mediaPath': state.mediaPath},
      );
    }
    if (state is AudioComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        extra: {'mediaPath': state.mediaPath},
      );
    }
    if (state is CodeBlockComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        extra: {'code': state.controller.text, 'language': state.languageId},
      );
    }
    if (state is MathComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        extra: {'formula': state.controller.text},
      );
    }
    if (state is EmbedComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        extra: {'content': state.content},
      );
    }
    if (state is LinkComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        extra: {'url': state.url, 'title': state.title},
      );
    }
    if (state is ListItemComponentState) {
      return ComponentSnapshot._(
        typeKey: component.def.key,
        delta: component.textDelta,
        extra: {
          'nestingLevel': state.nestingLevel,
          if (state is BulletedListComponentState) 'symbol': state.symbol,
          if (state is NumberedListComponentState)
            'numberStyle': state.numberStyle,
          if (state is NumberedListComponentState &&
              state.customSequenceNumber != null)
            'customSequenceNumber': state.customSequenceNumber,
          if (state is ChecklistComponentState) 'checked': state.isChecked,
        },
      );
    }
    // Plain text-based components (title, heading, text, lists, etc.).
    return ComponentSnapshot._(
      typeKey: component.def.key,
      delta: component.textDelta,
    );
  }

  /// Builds a brand-new [ComponentBox] (with a fresh id) from this snapshot.
  ComponentBox instantiate() {
    final component = InbuiltComponents.prepareCompoent(
      const Uuid().v4(),
      typeKey,
    );
    final state = component.state;

    if (state is QuoteComponentState) {
      final authorDelta = extra['authorDelta'] as List<dynamic>?;
      if (authorDelta != null) {
        state.author.controller.document = Document.fromJson(authorDelta);
      }
    } else if (state is ImageComponentState) {
      state.mediaPath = extra['mediaPath'] as String?;
      state.imageSize = extra['imageSize'] as String?;
      state.width = extra['width'] as int?;
      state.height = extra['height'] as int?;
    } else if (state is VideoComponentState) {
      state.mediaPath = extra['mediaPath'] as String?;
    } else if (state is AudioComponentState) {
      state.mediaPath = extra['mediaPath'] as String?;
    } else if (state is CodeBlockComponentState) {
      state.controller.text = extra['code'] as String? ?? '';
      state.setLanguage(extra['language'] as String? ?? 'plaintext');
    } else if (state is MathComponentState) {
      state.controller.text = extra['formula'] as String? ?? '';
    } else if (state is EmbedComponentState) {
      state.setContent(extra['content'] as String? ?? '');
    } else if (state is LinkComponentState) {
      state.setValues(
        url: extra['url'] as String? ?? '',
        title: extra['title'] as String?,
      );
    }
    if (state is ListItemComponentState) {
      final nestingLevel = extra['nestingLevel'];
      if (nestingLevel is num) {
        state.nestingLevel = nestingLevel.toInt();
      }
      if (state is BulletedListComponentState) {
        state.symbol = extra['symbol'] as String? ?? '•';
      } else if (state is NumberedListComponentState) {
        state.numberStyle = extra['numberStyle'] as String? ?? '1.';
        final customNumber = extra['customSequenceNumber'];
        if (customNumber is num) {
          state.setCustomSequenceNumber(customNumber.toInt());
        }
      } else if (state is ChecklistComponentState) {
        state.isChecked = extra['checked'] as bool? ?? false;
      }
    }

    final box = ComponentBox(component: component, delta: delta);
    box.hasFocusBar = extra['focusBar'] == true;
    return box;
  }

  Map<String, dynamic> toJson() => {
    'type': typeKey,
    if (delta != null) 'delta': delta,
    if (extra.isNotEmpty) 'extra': extra,
  };

  factory ComponentSnapshot.fromJson(Map<String, dynamic> json) {
    final rawExtra = json['extra'];
    return ComponentSnapshot._(
      typeKey: json['type'] as String,
      delta: (json['delta'] as List?)?.cast<dynamic>(),
      extra: rawExtra is Map ? Map<String, dynamic>.from(rawExtra) : const {},
    );
  }
}
