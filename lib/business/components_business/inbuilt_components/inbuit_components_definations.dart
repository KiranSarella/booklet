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
'- Dashed List',
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


class DashedListComponentDef extends ComponentDef {
  @override
  String get key => "dashed_list";

  @override
  String get name => "- Dashed List";

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


class QuoteComponentDef extends ComponentDef {
  @override
  String get key => "quote";

  @override
  String get name => "❝Quote❞";

  @override
  ComponentType get type => ComponentType.text;
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
