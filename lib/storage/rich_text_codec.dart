/// Represents an inline text styling span with offset and length.
class StyleSpan {
  const StyleSpan({
    required this.start,
    required this.length,
    required this.attributes,
  });

  final int start;
  final int length;
  final Map<String, dynamic> attributes;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'start': start,
      'length': length,
    };
    if (attributes.length == 1 && attributes.values.first == true) {
      json['style'] = attributes.keys.first;
    }
    json['attributes'] = attributes;
    return json;
  }

  factory StyleSpan.fromJson(Map<String, dynamic> json) {
    final start = (json['start'] as num?)?.toInt() ?? 0;
    // Support both 'length' and common typo 'lenght'
    final length =
        (json['length'] as num? ?? json['lenght'] as num?)?.toInt() ?? 0;

    final attrs = <String, dynamic>{};
    if (json['attributes'] is Map) {
      attrs.addAll(Map<String, dynamic>.from(json['attributes'] as Map));
    }
    if (json['style'] is String) {
      attrs[json['style'] as String] = true;
    } else if (json['style'] is Map) {
      attrs.addAll(Map<String, dynamic>.from(json['style'] as Map));
    }

    return StyleSpan(
      start: start,
      length: length,
      attributes: attrs,
    );
  }
}

/// Represents plain text content accompanied by inline style spans.
class RichTextData {
  const RichTextData({
    required this.content,
    required this.styles,
  });

  final String content;
  final List<StyleSpan> styles;

  Map<String, dynamic> toJson() => {
    'content': content,
    if (styles.isNotEmpty) 'styles': styles.map((s) => s.toJson()).toList(),
  };

  factory RichTextData.fromJson(Map<String, dynamic> json) {
    final content =
        json['content'] as String? ?? json['text'] as String? ?? '';
    final rawStyles = json['styles'] ?? json['spans'];

    final styles = <StyleSpan>[];
    if (rawStyles is List) {
      for (final rawSpan in rawStyles.whereType<Map>()) {
        styles.add(StyleSpan.fromJson(Map<String, dynamic>.from(rawSpan)));
      }
    }

    return RichTextData(content: content, styles: styles);
  }
}

/// Bidirectional converter between Quill Delta operations and [RichTextData].
class RichTextCodec {
  const RichTextCodec._();

  /// Converts a Quill Delta JSON list into plain text and style spans.
  static RichTextData deltaToRichText(List<dynamic> delta) {
    final rawOps = <({String text, Map<String, dynamic> attributes})>[];
    for (final rawOp in delta) {
      if (rawOp is! Map) continue;
      final op = Map<String, dynamic>.from(rawOp);
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = op['attributes'] is Map
          ? Map<String, dynamic>.from(op['attributes'] as Map)
          : <String, dynamic>{};
      rawOps.add((text: insert, attributes: attrs));
    }

    // Quill documents always end with a mandatory '\n'. Remove only that trailing newline.
    if (rawOps.isNotEmpty) {
      final last = rawOps.last;
      if (last.text.endsWith('\n')) {
        final trimmed = last.text.substring(0, last.text.length - 1);
        if (trimmed.isEmpty) {
          rawOps.removeLast();
        } else {
          rawOps[rawOps.length - 1] = (
            text: trimmed,
            attributes: last.attributes,
          );
        }
      }
    }

    final buffer = StringBuffer();
    final styles = <StyleSpan>[];
    var currentOffset = 0;

    for (final op in rawOps) {
      final text = op.text;
      final len = text.length;
      if (len == 0) continue;

      buffer.write(text);

      // Filter out block-only attributes like align, header, list
      final inlineAttrs = Map<String, dynamic>.from(op.attributes)
        ..removeWhere(
          (key, _) => key == 'align' || key == 'header' || key == 'list',
        );

      if (inlineAttrs.isNotEmpty) {
        styles.add(
          StyleSpan(
            start: currentOffset,
            length: len,
            attributes: inlineAttrs,
          ),
        );
      }
      currentOffset += len;
    }

    return RichTextData(content: buffer.toString(), styles: styles);
  }

  /// Recreates a Quill Delta JSON list from [RichTextData].
  static List<Map<String, dynamic>> richTextToDelta(RichTextData data) {
    final content = data.content;
    if (content.isEmpty) {
      return [
        {'insert': '\n'},
      ];
    }

    if (data.styles.isEmpty) {
      return [
        {'insert': '$content\n'},
      ];
    }

    // Collect all boundary points within valid string bounds
    final splitPoints = <int>{0, content.length};
    for (final span in data.styles) {
      if (span.length <= 0) continue;
      final start = span.start.clamp(0, content.length);
      final end = (span.start + span.length).clamp(0, content.length);
      if (start < end) {
        splitPoints.add(start);
        splitPoints.add(end);
      }
    }

    final sortedPoints = splitPoints.toList()..sort();
    final ops = <Map<String, dynamic>>[];

    for (var i = 0; i < sortedPoints.length - 1; i++) {
      final start = sortedPoints[i];
      final end = sortedPoints[i + 1];
      if (start >= end) continue;

      final chunk = content.substring(start, end);
      final mergedAttrs = <String, dynamic>{};

      for (final span in data.styles) {
        final sStart = span.start;
        final sEnd = span.start + span.length;
        if (sStart <= start && sEnd >= end) {
          mergedAttrs.addAll(span.attributes);
        }
      }

      if (mergedAttrs.isNotEmpty) {
        ops.add({'insert': chunk, 'attributes': mergedAttrs});
      } else {
        ops.add({'insert': chunk});
      }
    }

    // Merge adjacent operations that share identical attributes
    final mergedOps = <Map<String, dynamic>>[];
    for (final op in ops) {
      if (mergedOps.isEmpty) {
        mergedOps.add(Map<String, dynamic>.from(op));
        continue;
      }
      final prev = mergedOps.last;
      final prevAttrs = prev['attributes'] as Map<String, dynamic>? ?? {};
      final currAttrs = op['attributes'] as Map<String, dynamic>? ?? {};

      if (_mapsEqual(prevAttrs, currAttrs)) {
        prev['insert'] = '${prev['insert']}${op['insert']}';
      } else {
        mergedOps.add(Map<String, dynamic>.from(op));
      }
    }

    // Ensure document concludes with trailing '\n' as required by Quill
    if (mergedOps.isEmpty) {
      mergedOps.add({'insert': '\n'});
    } else {
      final last = mergedOps.last;
      final lastAttrs = last['attributes'] as Map<String, dynamic>?;
      if (lastAttrs == null || lastAttrs.isEmpty) {
        last['insert'] = '${last['insert']}\n';
      } else {
        mergedOps.add({'insert': '\n'});
      }
    }

    return mergedOps;
  }

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || b[key] != a[key]) return false;
    }
    return true;
  }
}

