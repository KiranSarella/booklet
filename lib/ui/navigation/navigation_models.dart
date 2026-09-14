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
}
