import 'package:flutter/material.dart';

import 'package:booklet/application/editor_controller.dart';
import 'package:booklet/ui/detail/assets_viewer/assets_viewer.dart';
import 'package:booklet/ui/detail/editor/editor_view.dart';

class BaseDetailView extends StatelessWidget {
  const BaseDetailView({
    super.key,
    required this.controller,
    required this.isReadOnly,
    this.editorKey,
  });

  final EditorController controller;
  final bool isReadOnly;
  final GlobalKey<EditorViewState>? editorKey;

  @override
  Widget build(BuildContext context) {
    final showAssets =
        controller.viewModel.navigation.selectedNode?.isAssetsFolder == true;
    return showAssets
        ? AssetsViewer(
            controller: controller.assetManagerController,
            isReadOnly: isReadOnly,
          )
        : EditorView(key: editorKey, controller: controller);
  }
}
