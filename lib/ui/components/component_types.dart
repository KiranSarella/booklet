import 'package:flutter/material.dart';

class ComponentTypes {
  static const double _baseFontSize = 14;

  static String getTitleFor(String componentTypeId) {
    switch (componentTypeId) {
      case 'title':
        return 'Title';
      case 'heading':
        return 'Heading';
      case 'subheading':
        return 'Subheading';
      case 'inline_heading':
        return 'Inline Heading';
      case 'subtitle':
        return 'Subtitle';
      case 'label':
        return 'Label';
      case 'text':
        return 'Text';
      case 'bulleted_list':
        return '- Bulleted List';
      case 'numbered_list':
        return '1. Numbered List';
      case 'checklist':
        return '🗸 Checklist';
      case 'block_text':
        return 'Block Text';
      case 'location':
        return '📍 Location';
      case 'image':
        return 'Image';
      case 'caption':
        return 'Caption';
      case 'footnote':
        return 'Footnote';
      default:
        return componentTypeId;
    }
  }

  static String? getIdForTitle(String title) {
    switch (title) {
      case 'Title':
        return 'title';
      case 'Heading':
        return 'heading';
      case 'Subheading':
        return 'subheading';
      case 'Inline Heading':
        return 'inline_heading';
      case 'Subtitle':
        return 'subtitle';
      case 'Label':
        return 'label';
      case 'Text':
        return 'text';
      case '- Bulleted List':
        return 'bulleted_list';
      case '1. Numbered List':
        return 'numbered_list';
      case '🗸 Checklist':
        return 'checklist';
      case 'Block Text':
        return 'block_text';
      case '📍 Location':
        return 'location';
      case 'Image':
        return 'image';
      case 'Caption':
        return 'caption';
      case 'Footnote':
        return 'footnote';
      default:
        return null;
    }
  }

  static TextStyle styleForComponent(String componentTypeId) {
    switch (componentTypeId) {
      case 'title':
        return const TextStyle(
          fontSize: _baseFontSize * 2.2,
          height: 1.2,
          fontWeight: FontWeight.w800,
        );
      case 'heading':
        return const TextStyle(
          fontSize: _baseFontSize * 1.75,
          fontWeight: FontWeight.w800,
        );
      case 'subheading':
        return const TextStyle(
          fontSize: _baseFontSize * 1.35,
          fontWeight: FontWeight.w700,
        );
      case 'inline_heading':
        return const TextStyle(
          fontSize: _baseFontSize * 1.15,
          fontWeight: FontWeight.w700,
        );
      case 'subtitle':
        return const TextStyle(fontSize: _baseFontSize * 1.35, height: 1);
      case 'label':
        return const TextStyle(
          fontFamily: 'Menlo',
          fontSize: _baseFontSize * 1.1,
        );
      case 'caption':
        return const TextStyle(
          fontSize: _baseFontSize * 0.9,
          fontWeight: FontWeight.w300,
        );
      case 'footnote':
        return const TextStyle(
          fontSize: _baseFontSize * 0.8,
          fontWeight: FontWeight.w200,
        );
      case 'block_text':
        return const TextStyle(
          fontFamily: 'Menlo',
          letterSpacing: 1.2,
          height: 0.9,
        );
      default:
        return const TextStyle(fontSize: _baseFontSize);
    }
  }
}
