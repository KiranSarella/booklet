enum ComponentType { text, media }

enum ComponentKind { inbuilt, composed }

abstract class ComponentDef {
  ComponentKind get kind => ComponentKind.inbuilt;
  String get key;
  String get name;
  String get placeholder => name;
  ComponentType get type;
}
