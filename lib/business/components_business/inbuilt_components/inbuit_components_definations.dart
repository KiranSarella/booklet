import 'package:booklet/business/components_business/component_def.dart';

/*

## components

'Title',
'Heading',
'Subheading',
'Inline Heading',
'Subtitle',
'Label',
'Text',
'* Bulleted List',
'1. Numbered List',
'🗸 Checklist',
'┃ Focus',
'Block Text',
'❝Quote❞',
'📍 Location',
'Caption',
'Footnote',

*/

class TitleComponentDef extends ComponentDef {
  @override
  String get key => "title";

  @override
  String get name => "Title";

  @override
  ComponentType get type => ComponentType.text;
}

class HeadingComponentDef extends ComponentDef {
  @override
  String get key => "heading";

  @override
  String get name => "Heading";

  @override
  ComponentType get type => ComponentType.text;
}

class SubheadingComponentDef extends ComponentDef {
  @override
  String get key => "subheading";

  @override
  String get name => "Subheading";

  @override
  ComponentType get type => ComponentType.text;
}

class InlineHeadingComponentDef extends ComponentDef {
  @override
  String get key => "inline_heading";

  @override
  String get name => "Inline Heading";

  @override
  ComponentType get type => ComponentType.text;
}

class SubtitleComponentDef extends ComponentDef {
  @override
  String get key => "subtitle";

  @override
  String get name => "Subtitle";

  @override
  ComponentType get type => ComponentType.text;
}

class LabelComponentDef extends ComponentDef {
  @override
  String get key => "label";

  @override
  String get name => "Label";

  @override
  ComponentType get type => ComponentType.text;
}

class TextComponentDef extends ComponentDef {
  @override
  String get key => "text";

  @override
  String get name => "Text";

  @override
  ComponentType get type => ComponentType.text;
}

class BulletedListComponentDef extends ComponentDef {
  @override
  String get key => "bulleted_list";

  @override
  String get name => "- Bulleted List";

  @override
  ComponentType get type => ComponentType.text;
}

class NumberedListComponentDef extends ComponentDef {
  @override
  String get key => "numbered_list";

  @override
  String get name => "1. Numbered List";

  @override
  ComponentType get type => ComponentType.text;
}

class ChecklistComponentDef extends ComponentDef {
  @override
  String get key => "checklist";

  @override
  String get name => "🗸 Checklist";

  @override
  ComponentType get type => ComponentType.text;
}

class FocusComponentDef extends ComponentDef {
  @override
  String get key => "focus";

  @override
  String get name => "┃ Focus";

  @override
  ComponentType get type => ComponentType.text;
}

class BlockTextComponentDef extends ComponentDef {
  @override
  String get key => "block_text";

  @override
  String get name => "Block Text";

  @override
  ComponentType get type => ComponentType.text;
}

class CodeBlockComponentDef extends ComponentDef {
  @override
  String get key => "code_block";

  @override
  String get name => "Code Block";

  @override
  ComponentType get type => ComponentType.text;
}

class MathComponentDef extends ComponentDef {
  @override
  String get key => "math";

  @override
  String get name => "Math Block";

  @override
  ComponentType get type => ComponentType.text;
}

class QuoteComponentDef extends ComponentDef {
  @override
  String get key => "quote";

  @override
  String get name => "❝Quote❞";

  @override
  ComponentType get type => ComponentType.text;
}

class ImageComponentDef extends ComponentDef {
  @override
  String get key => "image";

  @override
  String get name => "Image";

  @override
  ComponentType get type => ComponentType.media;
}

class VideoComponentDef extends ComponentDef {
  @override
  String get key => "video";

  @override
  String get name => "Video";

  @override
  ComponentType get type => ComponentType.media;
}

class AudioComponentDef extends ComponentDef {
  @override
  String get key => "audio";

  @override
  String get name => "Audio";

  @override
  ComponentType get type => ComponentType.media;
}

class EmbedComponentDef extends ComponentDef {
  @override
  String get key => "embed";

  @override
  String get name => "Embed";

  @override
  ComponentType get type => ComponentType.media;
}

class LinkComponentDef extends ComponentDef {
  @override
  String get key => "link";

  @override
  String get name => "Link";

  @override
  ComponentType get type => ComponentType.media;
}

class LocationComponentDef extends ComponentDef {
  @override
  String get key => "location";

  @override
  String get name => "📍 Location";

  @override
  ComponentType get type => ComponentType.text;
}

class CaptionComponentDef extends ComponentDef {
  @override
  String get key => "caption";

  @override
  String get name => "Caption";

  @override
  ComponentType get type => ComponentType.text;
}

class FootnoteComponentDef extends ComponentDef {
  @override
  String get key => "footnote";

  @override
  String get name => "Footnote";

  @override
  ComponentType get type => ComponentType.text;
}
