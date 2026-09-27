import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/application/app.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/ui/base_view.dart';
import 'package:booklet/ui/document_toolbar.dart';
import 'package:booklet/ui/page_settings/page_settings_view.dart';
import 'package:booklet/ui/page_settings/page_settings_vm.dart';
import 'package:booklet/ui/start_booklet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final documentSettingsController = DocumentSettingsController();
  final pageSettingsController = PageSettingsController(
    documentSettingsController,
  );
  runApp(
    MainApp(
      application: App(pageSettingsController, documentSettingsController),
    ),
  );
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.application.documentSettingsController.updateSystemBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    widget.application.documentSettingsController.load();
    widget.application.editorTheme.load();
  }

  Future<void> _openBookletFromStartup() async {
    await widget.application.openBooklet();
  }

  @override
  void didChangePlatformBrightness() {
    widget.application.documentSettingsController.updateSystemBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      builder: (context) => PageSettingsDialog(
        viewModel: PageSettingsVM(
          pageSettingsController: widget.application.editorTheme,
          documentSettingsController: widget.application.documentSettingsController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.application,
        widget.application.documentSettingsController,
      ]),
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
        themeMode: widget.application.documentSettingsController.themeMode,
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
                          controller: widget.application.editorController,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 102,
                      child: DocumentToolbar(
                        key: _documentToolbarKey,
                        controller: widget.application.editorController,
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
