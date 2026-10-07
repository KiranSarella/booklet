
enum ComponentType { 
  text, media
}

abstract class ComponentDef {
  String get key;
  String get name;
  String get placeholder => name;
  ComponentType get type;
}



