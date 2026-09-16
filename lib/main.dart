import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/ui/app/booklet_editor/booklet_editor.dart';
import 'package:booklet/ui/app/editor_themes/editor_themes.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _bookletEditorKey = GlobalKey<BookletEditorState>();
  final EditorTheme _editorTheme = EditorTheme();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editorTheme.updateSystemBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    _editorTheme.load();
  }

  @override
  void didChangePlatformBrightness() {
    _editorTheme.updateSystemBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) {
                  _bookletEditorKey.currentState?.dismissOptionsMenu();
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
                      width: double.infinity,
                      height: double.infinity,
                      child: BookletEditor(
                        key: _bookletEditorKey,
                        editorTheme: _editorTheme,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 76,
                    child: Tooltip(
                      message: 'Edit theme',
                      child: Material(
                        color: Theme.of(context).colorScheme.surfaceContainer,
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
