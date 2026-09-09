import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/ui/editor/booklet_editor/booklet_editor.dart';
import 'package:booklet/ui/editor/editor_themes/editor_themes.dart';
import 'package:booklet/ui/editor/options_dock/opitons_dock.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _optionsDockKey = GlobalKey<OptionsDockState>();
  final _bookletEditorKey = GlobalKey<BookletEditorState>();
  final EditorTheme _editorTheme = EditorTheme();
  bool _hasSelection = false;

  @override
  void dispose() {
    _editorTheme.dispose();
    super.dispose();
  }

  void _showThemeEditor() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }

    showDialog<void>(
      context: navigatorContext,
      builder: (context) => EditorThemeDialog(editorTheme: _editorTheme),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        // backgroundColor: const Color(0xFFF3F6FF),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        body: SafeArea(
          child: Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  _optionsDockKey.currentState?.dismissMenu();
                  return null;
                },
              ),
            },
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
              },
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: 480,
                      height: double.infinity,
                      child: BookletEditor(
                        key: _bookletEditorKey,
                        editorTheme: _editorTheme,
                        onSelectionChanged: (hasSelection) {
                          setState(() => _hasSelection = hasSelection);
                        },
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: OptionsDock(
                      key: _optionsDockKey,
                      onComponentSelected: (type) {
                        _bookletEditorKey.currentState
                            ?.addComponentBelowSelected(type);
                      },
                      onComponentTransformed: (type) {
                        _bookletEditorKey.currentState
                            ?.transformSelectedComponent(type);
                      },
                      onComponentDeleted: () {
                        _bookletEditorKey.currentState
                            ?.deleteSelectedComponent();
                      },
                      hasSelection: _hasSelection,
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 76,
                    child: Tooltip(
                      message: 'Edit theme',
                      child: Material(
                        color: const Color(0xFFEDEDED),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _showThemeEditor,
                          borderRadius: BorderRadius.circular(12),
                          child: const SizedBox(
                            width: 52,
                            height: 44,
                            child: Icon(Icons.palette_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
