import 'package:booklet/ui/app/options_dock/add_component_menu.dart';
import 'package:flutter/material.dart';

class OptionsDock extends StatefulWidget {
  const OptionsDock({
    super.key,
    required this.onComponentSelected,
    required this.onComponentTransformed,
    required this.onComponentDeleted,
    required this.hasSelection,
  });

  final ValueChanged<String> onComponentSelected;
  final ValueChanged<String> onComponentTransformed;
  final VoidCallback onComponentDeleted;
  final bool hasSelection;

  @override
  State<OptionsDock> createState() => OptionsDockState();
}

class OptionsDockState extends State<OptionsDock> {
  String? _openMenu;

  void dismissMenu() {
    if (_openMenu != null) {
      setState(() => _openMenu = null);
    }
  }

  void _toggleMenu(String menu) {
    setState(() => _openMenu = _openMenu == menu ? null : menu);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_openMenu != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismissMenu,
              child: const SizedBox.expand(),
            ),
          ),
        if (_openMenu != null) ...[
          Positioned(
            top: 12,
            right: 78,
            child: AddComponentMenu(
              title: _openMenu == 'add' ? 'Components' : 'Transform to',
              onSelected: (component) {
                if (_openMenu == 'add') {
                  widget.onComponentSelected(component);
                } else {
                  widget.onComponentTransformed(component);
                }
                dismissMenu();
              },
            ),
          ),
        ],
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockButton(
                icon: Icons.add,
                color: Colors.blue,
                tooltip: 'Add component',
                onPressed: () => _toggleMenu('add'),
              ),
              const SizedBox(height: 20),
              _DockButton(
                icon: Icons.swap_horiz,
                color: Colors.amber.shade700,
                tooltip: 'Transform component',
                onPressed: widget.hasSelection
                    ? () => _toggleMenu('transform')
                    : null,
                enabled: widget.hasSelection,
              ),
              const SizedBox(height: 80),
              _DockButton(
                icon: Icons.delete_outline,
                color: Colors.red,
                tooltip: 'Delete component',
                onPressed: widget.hasSelection
                    ? () {
                        widget.onComponentDeleted();
                        dismissMenu();
                      }
                    : null,
                enabled: widget.hasSelection,
              ),
              const SizedBox(height: 80),
              _DockButton(
                icon: Icons.more_horiz,
                color: Colors.black87,
                tooltip: 'More options',
                onPressed: dismissMenu,
                height: 36,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.enabled = true,
    this.height = 44,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? Theme.of(context).colorScheme.surfaceContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 52,
            height: height,
            child: Icon(
              icon,
              color: enabled ? color : Colors.grey.shade400,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
