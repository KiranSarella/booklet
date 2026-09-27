import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_types.dart';
import 'package:booklet/ui/components/inbuilt_component_objects.dart';
import 'package:booklet/ui/components/code_block_component.dart';
import 'package:booklet/ui/components/math_component.dart';
import 'package:booklet/ui/components/audio_component.dart';
import 'package:booklet/ui/components/embed_component.dart';
import 'package:booklet/ui/components/image_component.dart';
import 'package:booklet/ui/components/video_component.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/business/components_business/component_def.dart';

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
      case 'code_block':
        return CodeBlockComponent(id: id);
      case 'math':
        return MathComponent(id: id);
      case 'quote':
        return QuoteComponent(id: id);
      case 'image':
        return ImageComponent(id: id);
      case 'video':
        return VideoComponent(id: id);
      case 'audio':
        return AudioComponent(id: id);
      case 'embed':
        return EmbedComponent(id: id);
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

  static List<ComponentDef> getComponentMenuItems() {
    return [
      TitleComponentDef(),
      HeadingComponentDef(),
      SubheadingComponentDef(),
      InlineHeadingComponentDef(),
      SubtitleComponentDef(),
      LabelComponentDef(),
      TextComponentDef(),
      DashedListComponentDef(),
      NumberedListComponentDef(),
      ChecklistComponentDef(),
      FocusComponentDef(),
      BlockTextComponentDef(),
      CodeBlockComponentDef(),
      MathComponentDef(),
      QuoteComponentDef(),
      ImageComponentDef(),
      VideoComponentDef(),
      AudioComponentDef(),
      EmbedComponentDef(),
      LocationComponentDef(),
      CaptionComponentDef(),
      FootnoteComponentDef(),
    ];
  }
}
