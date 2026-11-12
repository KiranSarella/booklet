import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/components/composed/composition.dart';
import 'package:booklet/ui/components/composed/composition_canvas.dart';
import 'package:flutter/material.dart';
import 'package:booklet/ui/components/inbuilt_components/inbuilt_components.dart';

class AddComponentMenu extends StatefulWidget {
  const AddComponentMenu({
    super.key,
    required this.title,
    required this.onSelected,
    this.textOnly = false,
    this.isReadOnly = false,
    this.theme,
    this.documentPath,
    this.documentComponents = const [],
  });

  static const double baseFontSize = 14;

  final String title;
  final ValueChanged<String> onSelected;
  final bool textOnly;
  final bool isReadOnly;
  final PageSettingsController? theme;
  final String? documentPath;
  final List<CompositionTemplate> documentComponents;

  List<String> get componentTypes => textOnly
      ? _componentTypes
            .where(
              (key) =>
                  key == 'link' ||
                  InbuiltComponents.getComponentMenuItems()
                          .firstWhere((definition) => definition.key == key)
                          .type
                          .name ==
                      'text',
            )
            .toList(growable: false)
      : _componentTypes;

  static final List<String> _componentTypes =
      InbuiltComponents.getComponentMenuItems()
          .map((definition) => definition.key)
          .toList(growable: false);

  @override
  State<AddComponentMenu> createState() => _AddComponentMenuState();

  static String titleforkey(String key) =>
      InbuiltComponents.getComponentMenuItems()
          .firstWhere((e) => e.key == key)
          .name;
}

class _AddComponentMenuState extends State<AddComponentMenu> {
  static const baseFontSize = AddComponentMenu.baseFontSize;
  String query = '';
  bool composed = false;
  bool loading = true;
  String? error;
  List<CompositionTemplate> documentTemplates = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      await CompositionLibrary.load();
      final bundled = widget.documentPath == null
          ? <CompositionTemplate>[]
          : await BookletFile.loadDocumentComponents(widget.documentPath!);
      documentTemplates = {
        for (final template in [...bundled, ...widget.documentComponents])
          CompositionLibrary.registerDocument(template)
              .id: CompositionLibrary.registerDocument(
            template,
          ),
      }.values.toList();
    } catch (_) {
      error = 'Could not load saved components.';
    }
    if (mounted) setState(() => loading = false);
  }

  List<String> get componentTypes => widget.componentTypes;

  static String titleforkey(String key) {
    return InbuiltComponents.getComponentMenuItems()
        .firstWhere((definition) => definition.key == key)
        .name;
  }

  @override
  Widget build(BuildContext context) {
    final readOnly =
        widget.isReadOnly ||
        widget.theme?.documentSettingsController.isReadOnly == true;
    final inbuilt = componentTypes
        .where((key) => titleforkey(key).toLowerCase().contains(query))
        .toList();
    final templates = CompositionLibrary.templates
        .where((e) => e.name.toLowerCase().contains(query))
        .toList();
    final documents = documentTemplates
        .where((e) => CompositionLibrary.personalCopyOf(e) == null)
        .where((e) => e.name.toLowerCase().contains(query))
        .toList();
    final searching = query.isNotEmpty;
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 300,
        height: 480,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search all components',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) =>
                    setState(() => query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              if (!widget.textOnly)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Inbuilt')),
                    ButtonSegment(value: true, label: Text('Composed')),
                  ],
                  selected: {composed},
                  onSelectionChanged: (v) => setState(() => composed = v.first),
                ),
              if (loading && !widget.textOnly) const LinearProgressIndicator(),
              if (error != null) Text(error!),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    if (!composed || searching || widget.textOnly) ...[
                      if (searching && !widget.textOnly) const Text('Inbuilt'),
                      for (final key in inbuilt)
                        ListTile(
                          dense: true,
                          title: Text(
                            titleforkey(key),
                            style: _styleForComponent(titleforkey(key)),
                          ),
                          onTap: readOnly ? null : () => widget.onSelected(key),
                        ),
                    ],
                    if (!widget.textOnly && (composed || searching)) ...[
                      const Text('My components'),
                      for (final template in templates)
                        ListTile(
                          leading: const Icon(
                            Icons.dashboard_customize_outlined,
                          ),
                          title: Text(template.name),
                          trailing: readOnly
                              ? null
                              : IconButton(
                                  tooltip: 'Edit composed component',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () async {
                                    final saved = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => CompositionCanvas(
                                        initialTemplate: template,
                                        theme: widget.theme,
                                      ),
                                    );
                                    if (saved == true && mounted) {
                                      setState(() {});
                                    }
                                  },
                                ),
                          onTap: readOnly
                              ? null
                              : () => widget.onSelected(template.key),
                        ),
                      if (templates.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No components in your library yet.'),
                        ),
                      const SizedBox(height: 8),
                      const Text('In this document'),
                      for (final template in documents)
                        ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(template.name),
                          onTap: readOnly
                              ? null
                              : () => widget.onSelected(template.key),
                          trailing: readOnly
                              ? null
                              : IconButton(
                                  tooltip:
                                      CompositionLibrary.personalCopyOf(
                                            template,
                                          ) ==
                                          null
                                      ? 'Add to personal components'
                                      : 'Already in personal components',
                                  icon: const Icon(
                                    Icons.person_add_alt_1_outlined,
                                    size: 18,
                                  ),
                                  onPressed:
                                      CompositionLibrary.personalCopyOf(
                                            template,
                                          ) !=
                                          null
                                      ? null
                                      : () async {
                                          try {
                                            await CompositionLibrary.addToPersonal(
                                              template,
                                            );
                                            if (mounted) setState(() {});
                                          } catch (_) {
                                            if (mounted) {
                                              setState(
                                                () => error = 'Could not add personal component. Please try again.',
                                              );
                                            }
                                          }
                                        },
                                ),
                        ),
                      if (documents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'No additional components in this document.',
                          ),
                        ),
                      if (templates.isEmpty && documents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'No composed components yet. Create your own layout.',
                          ),
                        ),
                    ],
                    if (searching &&
                        inbuilt.isEmpty &&
                        templates.isEmpty &&
                        documents.isEmpty)
                      const Text('No matching components'),
                  ],
                ),
              ),
              if (!readOnly && !widget.textOnly && (composed || searching))
                FilledButton.icon(
                  onPressed: loading || error != null
                      ? null
                      : () async {
                          final saved = await showDialog<bool>(
                            context: context,
                            builder: (_) =>
                                CompositionCanvas(theme: widget.theme),
                          );
                          if (saved == true && mounted) {
                            setState(() {
                              composed = true;
                            });
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Compose component'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _styleForComponent(String component) {
    switch (component) {
      case 'Title':
        return const TextStyle(
          fontSize: baseFontSize * 2.2,
          height: 1.2,
          fontWeight: FontWeight.w800,
        );
      case 'Heading':
        return const TextStyle(
          fontSize: baseFontSize * 1.75,
          fontWeight: FontWeight.w800,
        );
      case 'Heading 2':
        return const TextStyle(
          fontSize: baseFontSize * 1.55,
          fontWeight: FontWeight.w800,
        );
      case 'Subheading':
        return const TextStyle(
          fontSize: baseFontSize * 1.35,
          fontWeight: FontWeight.w700,
        );
      case 'Subheading 2':
        return const TextStyle(
          fontSize: baseFontSize * 1.25,
          fontWeight: FontWeight.w700,
        );
      case 'Inline Heading':
        return const TextStyle(
          fontSize: baseFontSize * 1.15,
          fontWeight: FontWeight.w700,
        );
      case 'Subtitle':
        return const TextStyle(fontSize: baseFontSize * 1.35, height: 1);
      case 'Label':
        return const TextStyle(
          fontFamily: 'Menlo',
          fontSize: baseFontSize,
          // fontWeight: FontWeight.w600,
        );
      case 'Caption':
        return const TextStyle(
          fontSize: baseFontSize * 0.79,
          fontWeight: FontWeight.w400,
        );
      case 'Footnote':
        return const TextStyle(
          fontSize: baseFontSize * 0.7,
          fontWeight: FontWeight.w300,
        );
      case 'Block Text':
        return const TextStyle(
          fontFamily: 'Menlo',
          letterSpacing: 1.2,
          height: 0.9,
        );
      default:
        return const TextStyle(fontSize: baseFontSize);
    }
  }
}
