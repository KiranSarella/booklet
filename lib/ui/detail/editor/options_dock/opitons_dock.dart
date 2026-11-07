import 'package:booklet/ui/detail/editor/options_dock/add_component_menu.dart';
import 'package:flutter/material.dart';

class OptionsDock extends StatefulWidget {
  const OptionsDock({
    super.key,
    required this.onComponentSelected,
    required this.onComponentTransformed,
    required this.onFocusBarToggled,
    required this.onComponentDeleted,
    required this.onComponentsCopied,
    required this.onComponentsPasted,
    required this.onListStyleChanged,
    required this.hasSelection,
    required this.hasFocusBar,
    required this.canTransformSelection,
    required this.selectedListKind,
    required this.selectedListStyle,
    required this.selectedListStyleOptions,
    required this.canPaste,
    required this.isReadOnly,
    this.onHighlightAction,
    this.onHighlightSelected,
  });

  final ValueChanged<String> onComponentSelected;
  final ValueChanged<String> onComponentTransformed;
  final VoidCallback onFocusBarToggled;
  final VoidCallback onComponentDeleted;
  final VoidCallback onComponentsCopied;
  final VoidCallback onComponentsPasted;
  final ValueChanged<String> onListStyleChanged;
  final bool hasSelection;
  final bool hasFocusBar;
  final bool canTransformSelection;
  final String? selectedListKind;
  final String? selectedListStyle;
  final List<String> selectedListStyleOptions;
  final bool canPaste;
  final bool isReadOnly;
  final VoidCallback? onHighlightAction;
  final ValueChanged<Color?>? onHighlightSelected;

  @override
  State<OptionsDock> createState() => OptionsDockState();
}

class OptionsDockState extends State<OptionsDock> {
  String? _openMenu;
  Color _highlightColor = const Color(0xFFFFF59D);

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
    // Pale annotation colors need deeper counterparts on light toolbar surfaces.
    final iconTint = Theme.of(context).brightness == Brightness.light
        ? switch (_highlightColor.toARGB32()) {
            0xFFFFF59D => const Color(0xFFE0B800),
            0xFFA5D6A7 => const Color(0xFF2E7D32),
            0xFF90CAF9 => const Color(0xFF1565C0),
            0xFFF48FB1 => const Color(0xFFAD1457),
            _ => _highlightColor,
          }
        : _highlightColor;
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
          top: 82,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isReadOnly) ...[
                const _ReadOnlyIndicator(),
                const SizedBox(height: 20),
                TextFieldTapRegion(
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Highlight selected text',
                          icon: Icon(Icons.highlight, color: iconTint),
                          onPressed: () {
                            if (!widget.isReadOnly) return;
                            widget.onHighlightAction?.call();
                            widget.onHighlightSelected?.call(_highlightColor);
                          },
                        ),
                        const SizedBox(width: 36, child: Divider(height: 1)),
                        PopupMenuButton<Color>(
                          tooltip: 'Choose highlight color',
                          requestFocus: false,
                          constraints: const BoxConstraints(minWidth: 56),
                          onSelected: (color) {
                            if (widget.isReadOnly) {
                              setState(() => _highlightColor = color);
                            }
                          },
                          itemBuilder: (context) => [
                            for (final (name, color) in const [
                              ('Yellow', Color(0xFFFFF59D)),
                              ('Green', Color(0xFFA5D6A7)),
                              ('Blue', Color(0xFF90CAF9)),
                              ('Pink', Color(0xFFF48FB1)),
                            ])
                              PopupMenuItem(
                                value: color,
                                child: TextFieldTapRegion(
                                  child: Semantics(
                                    label: name,
                                    selected: color == _highlightColor,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                      child: color == _highlightColor
                                          ? const Icon(
                                              Icons.check,
                                              size: 18,
                                              color: Colors.black87,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          icon: Icon(Icons.arrow_drop_down, color: iconTint),
                        ),
                        const SizedBox(width: 36, child: Divider(height: 1)),
                        IconButton(
                          tooltip: 'Clear selected highlight',
                          icon: const Icon(Icons.format_color_reset),
                          onPressed: () {
                            if (!widget.isReadOnly) return;
                            widget.onHighlightAction?.call();
                            widget.onHighlightSelected?.call(null);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
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
                const SizedBox(height: 20),
                _DockButton(
                  icon: Icons.border_left,
                  color: Colors.red,
                  tooltip: widget.hasFocusBar
                      ? 'Remove focus bar'
                      : 'Add focus bar',
                  onPressed: widget.hasSelection
                      ? () {
                          widget.onFocusBarToggled();
                          dismissMenu();
                        }
                      : null,
                  enabled: widget.hasSelection,
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
        // color: Theme.of(context).colorScheme.surfaceContainer,
        // borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 52,
          height: 44,
          child: Icon(Icons.lock_outline, size: 20, color: Colors.red),
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
