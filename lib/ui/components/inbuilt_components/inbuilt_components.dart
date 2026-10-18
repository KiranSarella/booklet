import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_types.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/block_text_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/bulleted_list_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/caption_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/checklist_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/footnote_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/heading_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/code_block_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/inline_heading_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/label_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/location_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/math_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/audio_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/embed_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/link_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/image_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/numbered_list_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/subheading_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/subtitle_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/text_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/title_component.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/video_component.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/quote_component.dart';

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
      case 'bulleted_list':
        return BulletedListComponent(id: id);
      case 'numbered_list':
        return NumberedListComponent(id: id);
      case 'checklist':
        return ChecklistComponent(id: id);
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
      case 'link':
        return LinkComponent(id: id);
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
      BulletedListComponentDef(),
      NumberedListComponentDef(),
      ChecklistComponentDef(),
      BlockTextComponentDef(),
      CodeBlockComponentDef(),
      MathComponentDef(),
      QuoteComponentDef(),
      ImageComponentDef(),
      VideoComponentDef(),
      AudioComponentDef(),
      EmbedComponentDef(),
      LinkComponentDef(),
      LocationComponentDef(),
      CaptionComponentDef(),
      FootnoteComponentDef(),
    ];
  }
}
