
enum ComponentType { 
  text, media
}

abstract class ComponentDef {
  String get key;
  String get name;
  ComponentType get type;
}



