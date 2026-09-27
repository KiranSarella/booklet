import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/all.dart';

const _supportedLanguages = <String, String>{
  'plaintext': 'Plain text',
  'bash': 'Bash',
  'cpp': 'C++',
  'cs': 'C#',
  'css': 'CSS',
  'dart': 'Dart',
  'dockerfile': 'Dockerfile',
  'go': 'Go',
  'html': 'HTML',
  'java': 'Java',
  'javascript': 'JavaScript',
  'json': 'JSON',
  'kotlin': 'Kotlin',
  'markdown': 'Markdown',
  'php': 'PHP',
  'python': 'Python',
  'ruby': 'Ruby',
  'rust': 'Rust',
  'sql': 'SQL',
  'swift': 'Swift',
  'typescript': 'TypeScript',
  'xml': 'XML',
  'yaml': 'YAML',
};

String _normalizeLanguage(String? language) =>
    _supportedLanguages.containsKey(language) ? language! : 'plaintext';

class CodeBlockComponentState extends ComponentState {
  CodeBlockComponentState({String? code, String? language})
    : languageId = _normalizeLanguage(language),
      controller = CodeController(
        text: code ?? '',
        language: allLanguages[_normalizeLanguage(language)],
      );

  final CodeController controller;
  final FocusNode focusNode = FocusNode();
  String languageId;

  void setLanguage(String language) {
    languageId = _normalizeLanguage(language);
    controller.language = allLanguages[languageId];
  }

  @override
  String get output => controller.text;

  @override
  List<dynamic> get textDelta {
    final text = controller.text;
    return [
      {'insert': text.endsWith('\n') ? text : '$text\n'},
    ];
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class CodeBlockComponent implements Component {
  CodeBlockComponent({required this.id, String? code, String? language})
    : state = CodeBlockComponentState(code: code, language: language);

  @override
  final String id;

  @override
  final CodeBlockComponentState state;

  @override
  ComponentDef get def => CodeBlockComponentDef();

  @override
  Object get output => state.output;

  @override
  List<dynamic> get textDelta => state.textDelta;

  @override
  void initialize({List<dynamic>? delta}) {
    if (delta == null) {
      return;
    }
    final text = delta
        .whereType<Map>()
        .map((operation) => operation['insert'])
        .whereType<String>()
        .join();
    state.controller.text = text.endsWith('\n')
        ? text.substring(0, text.length - 1)
        : text;
  }

  @override
  void dispose() => state.dispose();

  @override
  Widget buildUI({
    required EditorTheme theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) {
    return CodeBlockComponentView(
      state: state,
      isSelected: isSelected,
      onSelect: onSelect,
    );
  }
}

class CodeBlockComponentView extends StatefulWidget {
  const CodeBlockComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
  });

  final CodeBlockComponentState state;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<CodeBlockComponentView> createState() => _CodeBlockComponentViewState();
}

class _CodeBlockComponentViewState extends State<CodeBlockComponentView> {
  static const _previewLineLimit = 10;
  bool _isExpanded = false;

  int get _lineCount =>
      '\n'.allMatches(widget.state.controller.text).length + 1;

  @override
  void initState() {
    super.initState();
    widget.state.controller.addListener(_onCodeChanged);
  }

  @override
  void didUpdateWidget(covariant CodeBlockComponentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.controller != widget.state.controller) {
      oldWidget.state.controller.removeListener(_onCodeChanged);
      widget.state.controller.addListener(_onCodeChanged);
    }
  }

  void _onCodeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.state.controller.removeListener(_onCodeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxLines = _isExpanded ? null : _previewLineLimit;
    final visibleLines = _lineCount.clamp(1, _previewLineLimit);
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.45,
      color: colorScheme.onSurface,
    );
    final codeField = CodeField(
      controller: widget.state.controller,
      focusNode: widget.state.focusNode,
      minLines: 1,
      maxLines: maxLines,
      wrap: false,
      gutterStyle: const GutterStyle(
        showLineNumbers: true,
        showErrors: false,
        showFoldingHandles: false,
      ),
      textStyle: codeStyle,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      background: Colors.transparent,
      cursorColor: colorScheme.primary,
    );
    final editor = _isExpanded
        ? codeField
        : SizedBox(
            height: visibleLines * codeStyle.fontSize! * codeStyle.height! + 40,
            child: codeField,
          );

    return Focus(
      onFocusChange: (hasFocus) {
        widget.state.isFocused = hasFocus;
        if (hasFocus) {
          widget.onSelect();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
          border: Border.all(
            color: widget.isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: widget.isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildToolbar(colorScheme),
            CodeTheme(
              data: CodeThemeData(
                styles: {
                  'root': codeStyle,
                  'keyword': TextStyle(color: colorScheme.primary),
                  'built_in': TextStyle(color: colorScheme.secondary),
                  'title': TextStyle(color: colorScheme.tertiary),
                  'string': TextStyle(color: colorScheme.tertiary),
                  'comment': TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  'number': TextStyle(color: colorScheme.secondary),
                },
              ),
              child: editor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(ColorScheme colorScheme) {
    final isLong = _lineCount > _previewLineLimit;
    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.code, size: 17, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.state.languageId,
              isDense: true,
              borderRadius: BorderRadius.circular(6),
              items: _supportedLanguages.entries
                  .map(
                    (language) => DropdownMenuItem<String>(
                      value: language.key,
                      child: Text(language.value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (language) {
                if (language == null) {
                  return;
                }
                widget.state.setLanguage(language);
                widget.onSelect();
              },
            ),
          ),
          const Spacer(),
          if (isLong)
            PopupMenuButton<bool>(
              tooltip: 'Code block options',
              onSelected: (expanded) {
                setState(() => _isExpanded = expanded);
                widget.onSelect();
              },
              itemBuilder: (context) => [
                PopupMenuItem<bool>(
                  value: !_isExpanded,
                  child: Text(_isExpanded ? 'Collapse code' : 'Show full code'),
                ),
              ],
              icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
