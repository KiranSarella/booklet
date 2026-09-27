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

// Uniformly shifts every surface tone toward gray, keeping their relative
// hierarchy (container levels) intact so nav/menus/toolbar stay consistent.
ColorScheme _applyGrayTint(ColorScheme scheme) {
  Color tint(Color color) => Color.lerp(color, const Color(0xFF9E9E9E), 0.32)!;
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
          documentSettingsController:
              widget.application.documentSettingsController,
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
        final lightScheme = documentSettingsController.isGray
            ? _applyGrayTint(baseLightScheme)
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
            colorScheme: lightScheme,
            scaffoldBackgroundColor: lightScheme.surface,
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
        );
      },
    );
  }
}
