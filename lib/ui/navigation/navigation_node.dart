import 'package:booklet/business/booklet_asset.dart';
import 'package:flutter/material.dart';

enum NavigationNodeType { group, page, assetsFolder }

enum PagePlacement { above, below, child }

class NavigationNode {
  NavigationNode.group({
    required this.title,
    this.icon = Icons.view_list_outlined,
  }) : type = NavigationNodeType.group,
       pageId = null,
       folderId = null;

  NavigationNode.page({
    required this.title,
    required this.pageId,
    this.icon = Icons.description_outlined,
  }) : type = NavigationNodeType.page,
       folderId = null;

  NavigationNode.assetsFolder({
    required this.title,
    required this.folderId,
    this.icon = Icons.folder_outlined,
  }) : type = NavigationNodeType.assetsFolder,
       pageId = null;

  final NavigationNodeType type;
  String title;
  final IconData icon;
  final String? pageId;
  final String? folderId;
  final List<NavigationNode> children = [];
  final List<BookletAsset> assets = [];
  bool isExpanded = true;

  bool get isGroup => type == NavigationNodeType.group;
  bool get isPage => type == NavigationNodeType.page;
  bool get isAssetsFolder => type == NavigationNodeType.assetsFolder;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    if (pageId != null) 'pageId': pageId,
    if (folderId != null) 'folderId': folderId,
    'isExpanded': isExpanded,
    if (isAssetsFolder)
      'assets': assets.map((asset) => asset.toJson()).toList(),
    'children': isAssetsFolder
        ? <Map<String, dynamic>>[]
        : children.map((child) => child.toJson()).toList(),
  };

  static NavigationNode fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final title = json['title'] as String? ?? 'New group';
    final node = switch (type) {
      'page' => NavigationNode.page(
        title: title,
        pageId: json['pageId'] as String? ?? '',
      ),
      'assetsFolder' => NavigationNode.assetsFolder(
        title: title,
        folderId: json['folderId'] as String? ?? '',
      ),
      _ => NavigationNode.group(title: title),
    };
    node.isExpanded = json['isExpanded'] as bool? ?? true;
    final assets = json['assets'];
    if (node.isAssetsFolder && assets is List) {
      node.assets.addAll(
        assets.whereType<Map>().map(
          (asset) => BookletAsset.fromJson(Map<String, dynamic>.from(asset)),
        ),
      );
    }
    final children = json['children'];
    if (!node.isAssetsFolder && children is List) {
      node.children.addAll(
        children.whereType<Map>().map(
          (child) => NavigationNode.fromJson(Map<String, dynamic>.from(child)),
        ),
      );
    }
    return node;
  }
}
