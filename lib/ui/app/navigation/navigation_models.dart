import 'package:flutter/material.dart';

enum NavigationNodeType { group, page }

enum PagePlacement { above, below, child }

class NavigationNode {
  NavigationNode.group({
    required this.title,
    this.icon = Icons.view_list_outlined,
  }) : type = NavigationNodeType.group,
       pageId = null;

  NavigationNode.page({
    required this.title,
    required this.pageId,
    this.icon = Icons.description_outlined,
  }) : type = NavigationNodeType.page;

  final NavigationNodeType type;
  String title;
  final IconData icon;
  final String? pageId;
  final List<NavigationNode> children = [];
  bool isExpanded = true;

  bool get isGroup => type == NavigationNodeType.group;
  bool get isPage => type == NavigationNodeType.page;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    if (pageId != null) 'pageId': pageId,
    'isExpanded': isExpanded,
    'children': children.map((child) => child.toJson()).toList(),
  };

  static NavigationNode fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final node = type == NavigationNodeType.page.name
        ? NavigationNode.page(
            title: json['title'] as String? ?? 'Untitled page',
            pageId: json['pageId'] as String? ?? '',
          )
        : NavigationNode.group(title: json['title'] as String? ?? 'New group');
    node.isExpanded = json['isExpanded'] as bool? ?? true;
    final children = json['children'];
    if (children is List) {
      node.children.addAll(
        children.whereType<Map>().map(
          (child) => NavigationNode.fromJson(Map<String, dynamic>.from(child)),
        ),
      );
    }
    return node;
  }
}
