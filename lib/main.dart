import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/application/app.dart';
import 'package:booklet/ui/base_view.dart';
import 'package:booklet/ui/document_toolbar.dart';
import 'package:booklet/ui/editor_themes/editor_themes.dart';
import 'package:booklet/ui/start_booklet.dart';

void main() {
  runApp(MainApp(application: App()));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key, required this.application});

  final App application;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _bookletEditorKey = GlobalKey<BaseViewState>();
  final _documentToolbarKey = GlobalKey<DocumentToolbarState>();
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

  Future<void> _openBookletFromStartup() async {
    widget.application.openBooklet();
    await _documentToolbarKey.currentState?.openBooklet();
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
    widget.application.dispose();
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
    return AnimatedBuilder(
      animation: widget.application,
      builder: (context, _) => MaterialApp(
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
                        child: BaseView(
                          key: _bookletEditorKey,
                          editorTheme: _editorTheme,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 102,
                      child: DocumentToolbar(
                        key: _documentToolbarKey,
                        editorKey: _bookletEditorKey,
                        onEditTheme: _showThemeEditor,
                      ),
                    ),
                    if (widget.application.screen == AppScreen.startup)
                      StartBooklet(
                        onCreateNew: widget.application.createBooklet,
                        onOpenExisting: _openBookletFromStartup,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
