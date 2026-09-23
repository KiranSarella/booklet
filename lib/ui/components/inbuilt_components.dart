import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_types.dart';
import 'package:booklet/ui/components/inbuilt_component_objects.dart';

class InbuiltComponents {
  static Component prepareCompoent(String id, String key) {
    final normalizedKey =
        ComponentTypes.getIdForTitle(key) ?? key.toLowerCase();
    switch (normalizedKey) {
      case 'title':
        return TitleComponent(id: id);
      case 'heading':
        return HeadingComponent(id: id);
      case 'subheading':
        return SubheadingComponent(id: id);
      case 'inline_heading':
        return InlineHeadingComponent(id: id);
      case 'subtitle':
        return SubtitleComponent(id: id);
      case 'label':
        return LabelComponent(id: id);
      case 'text':
        return TextComponent(id: id);
      case 'dashed_list':
        return DashedListComponent(id: id);
      case 'numbered_list':
        return NumberedListComponent(id: id);
      case 'checklist':
        return ChecklistComponent(id: id);
      case 'focus':
        return FocusComponent(id: id);
      case 'block_text':
        return BlockTextComponent(id: id);
      case 'location':
        return LocationComponent(id: id);
      case 'caption':
        return CaptionComponent(id: id);
      case 'footnote':
        return FootnoteComponent(id: id);
      default:
        return TextComponent(id: id);
    }
  }
}
