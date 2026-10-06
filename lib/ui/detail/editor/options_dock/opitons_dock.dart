import 'package:booklet/ui/detail/editor/options_dock/add_component_menu.dart';
import 'package:flutter/material.dart';

class OptionsDock extends StatefulWidget {
  const OptionsDock({
    super.key,
    required this.onComponentSelected,
    required this.onComponentTransformed,
    required this.onComponentDeleted,
    required this.onComponentsCopied,
    required this.onComponentsPasted,
    required this.onListStyleChanged,
    required this.onPageSettings,
    required this.hasSelection,
    required this.canTransformSelection,
    required this.selectedListKind,
    required this.selectedListStyle,
    required this.selectedListStyleOptions,
    required this.canPaste,
    required this.isReadOnly,
  });

  final ValueChanged<String> onComponentSelected;
  final ValueChanged<String> onComponentTransformed;
  final VoidCallback onComponentDeleted;
  final VoidCallback onComponentsCopied;
  final VoidCallback onComponentsPasted;
  final ValueChanged<String> onListStyleChanged;
  final VoidCallback onPageSettings;
  final bool hasSelection;
  final bool canTransformSelection;
  final String? selectedListKind;
  final String? selectedListStyle;
  final List<String> selectedListStyleOptions;
  final bool canPaste;
  final bool isReadOnly;

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
        if (_openMenu == 'list')
          Positioned(
            top: 12,
            right: 78,
            child: _ListOptionsMenu(
              kind: widget.selectedListKind!,
              selectedStyle: widget.selectedListStyle,
              options: widget.selectedListStyleOptions,
              onSelected: (style) {
                widget.onListStyleChanged(style);
                dismissMenu();
              },
            ),
          )
        else if (_openMenu != null) ...[
          Positioned(
            top: 12,
            right: 78,
            child: AddComponentMenu(
              title: _openMenu == 'add' ? 'Components' : 'Transform to',
              textOnly: _openMenu == 'transform',
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
              if (widget.isReadOnly)
                const _ReadOnlyIndicator()
              else ...[
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
                  onPressed: widget.canTransformSelection
                      ? () => _toggleMenu('transform')
                      : null,
                  enabled: widget.canTransformSelection,
                ),
                const SizedBox(height: 80),
                _DockButton(
                  icon: Icons.copy_outlined,
                  color: Colors.teal,
                  tooltip: 'Copy component(s)',
                  onPressed: widget.hasSelection
                      ? () {
                          widget.onComponentsCopied();
                          dismissMenu();
                        }
                      : null,
                  enabled: widget.hasSelection,
                ),
                const SizedBox(height: 20),
                _DockButton(
                  icon: Icons.content_paste,
                  color: Colors.teal,
                  tooltip: 'Paste component(s)',
                  onPressed: widget.canPaste
                      ? () {
                          widget.onComponentsPasted();
                          dismissMenu();
                        }
                      : null,
                  enabled: widget.canPaste,
                ),
                const SizedBox(height: 20),
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
                  onPressed: widget.selectedListKind == null
                      ? null
                      : () => _toggleMenu('list'),
                  enabled: widget.selectedListKind != null,
                  height: 36,
                ),
              ],
              const SizedBox(height: 20),
              _DockButton(
                icon: Icons.palette_outlined,
                color: Colors.indigo,
                tooltip: 'Page settings',
                onPressed: () {
                  widget.onPageSettings();
                  dismissMenu();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListOptionsMenu extends StatelessWidget {
  const _ListOptionsMenu({
    required this.kind,
    required this.selectedStyle,
    required this.options,
    required this.onSelected,
  });

  final String kind;
  final String? selectedStyle;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                kind == 'bullet' ? 'Bullet symbol' : 'Number format',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final option in options)
              InkWell(
                onTap: () => onSelected(option),
                child: SizedBox(
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: Text(option)),
                        if (option == selectedStyle)
                          const Icon(Icons.check, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyIndicator extends StatelessWidget {
  const _ReadOnlyIndicator();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Read-only',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 52,
          height: 44,
          child: Icon(Icons.lock_outline, size: 20),
        ),
      ),
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
