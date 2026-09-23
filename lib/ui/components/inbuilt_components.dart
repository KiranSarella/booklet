import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/inbuilt_component_objects.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';



class InbuiltComponents {



  static Component prepareCompoent(String id, String key) {
    key = key.toLowerCase();
    switch (key) {
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
      case 'text':
        return TextComponent(id: id);
      case 'focus':
        return FocusComponent(id: id);
      case 'label':
        return LabelComponent(id: id);
      case 'caption':
        return CaptionComponent(id: id);
      case 'footnote':
        return FootnoteComponent(id: id);
      
      default: 
      return TextComponent(id: id);
    }
  }

}

