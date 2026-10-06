import 'package:flutter/material.dart';

import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/detail/assets/asset_manager_view.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';

class BaseDetailView extends StatelessWidget {
  const BaseDetailView({super.key, required this.controller, this.editorKey});

  final EditorController controller;
  final GlobalKey<EditorViewState>? editorKey;

  @override
  Widget build(BuildContext context) {
    final showAssets =
        controller.viewModel.navigation.selectedNode?.isAssetsFolder == true;
    return showAssets
        ? AssetManagerView(controller: controller.assetManagerController)
        : EditorView(key: editorKey, controller: controller);
  }
}
