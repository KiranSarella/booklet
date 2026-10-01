import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/application/app.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/application/window_manager_service.dart';
import 'package:booklet/ui/base_view.dart';
import 'package:booklet/ui/document_settings/document_settings_view.dart';
import 'package:booklet/ui/document_settings/document_settings_vm.dart';
import 'package:booklet/ui/document_toolbar.dart';
import 'package:booklet/ui/page_settings/page_settings_view.dart';
import 'package:booklet/ui/page_settings/page_settings_vm.dart';
import 'package:booklet/ui/start_booklet.dart';

// Keeps gray appearance dark enough for the dark scheme's white foregrounds.
ColorScheme _applyGrayTint(ColorScheme scheme) {
  Color tint(Color color) =>
      Color.lerp(color, const Color.fromARGB(255, 103, 102, 102), 0.45)!;
  return scheme.copyWith(
    surface: tint(scheme.surface),
    surfaceDim: tint(scheme.surfaceDim),
    surfaceBright: tint(scheme.surfaceBright),
    surfaceContainerLowest: tint(scheme.surfaceContainerLowest),
    surfaceContainerLow: tint(scheme.surfaceContainerLow),
    surfaceContainer: tint(scheme.surfaceContainer),
    surfaceContainerHigh: tint(scheme.surfaceContainerHigh),
    surfaceContainerHighest: tint(scheme.surfaceContainerHighest),
  );
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Every window (the first one and any spawned via WindowManagerService)
  // goes through this same entry point; the window's own launch arguments
  // tell us which document (if any) it should open.
  final windowController = await WindowController.fromCurrentEngine();
  final documentPath = WindowManagerService.parseDocumentPath(
    windowController.arguments,
  );

  final documentSettingsController = DocumentSettingsController();
  final pageSettingsController = PageSettingsController(
    documentSettingsController,
  );
  final application = App(pageSettingsController, documentSettingsController);

  runApp(MainApp(application: application));

  if (documentPath != null) {
    unawaited(application.openBookletAtPath(documentPath));
  }
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
  final _windowManagerService = WindowManagerService();

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

  void _openInNewWindow() {
    unawaited(
      _windowManagerService.openDocumentInNewWindow(
        widget.application.editorController.documentPath,
      ),
    );
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
          documentSettingsController:
              widget.application.documentSettingsController,
        ),
      ),
    );
  }

  void _showDocumentSettings() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }

    showDialog<void>(
      context: navigatorContext,
      builder: (context) => DocumentSettingsDialog(
        viewModel: DocumentSettingsVM(
          settingsController: widget.application.documentSettingsController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final documentSettingsController =
        widget.application.documentSettingsController;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.application,
        documentSettingsController,
      ]),
      builder: (context, _) {
        final baseLightScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
        final baseGrayScheme = ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        );
        final colorScheme = documentSettingsController.isGray
            ? _applyGrayTint(baseGrayScheme)
            : baseLightScheme;

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
          theme: ThemeData(
            colorScheme: colorScheme,
            scaffoldBackgroundColor: colorScheme.surface,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: documentSettingsController.themeMode,
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
                            onShowDocumentSettings: _showDocumentSettings,
                            onShowPageSettings: _showThemeEditor,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 602,
                        child: DocumentToolbar(
                          controller: widget.application.editorController,
                          onOpenInNewWindow: _openInNewWindow,
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
        );
      },
    );
  }
}
