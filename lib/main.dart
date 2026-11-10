import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/application/app.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/application/open_file_service.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/application/window_manager_service.dart';
import 'package:booklet/ui/main_view.dart';
import 'package:booklet/ui/reader/reader_shell.dart';
import 'package:booklet/ui/start_booklet.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Every window (the first one and any spawned via WindowManagerService)
  // goes through this same entry point; the window's own launch arguments
  // tell us which document (if any) it should open.
  String? documentPath;
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    final windowController = await WindowController.fromCurrentEngine();
    documentPath = WindowManagerService.parseDocumentPath(
      windowController.arguments,
    );
  }

  final documentSettingsController = DocumentSettingsController(
    forceReadOnly: Platform.isAndroid,
  );
  final pageSettingsController = PageSettingsController(
    documentSettingsController,
  );
  final application = App(pageSettingsController, documentSettingsController);

  runApp(MainApp(application: application, initialDocumentPath: documentPath));
}

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.application,
    this.initialDocumentPath,
  });

  final App application;
  final String? initialDocumentPath;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _bookletEditorKey = GlobalKey<MainViewState>();
  final _windowManagerService = WindowManagerService();
  final _openFileService = OpenFileService();
  bool _checkingInitialDocument = true;
  int _openingDocuments = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.application.documentSettingsController.updateSystemBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    widget.application.documentSettingsController.load();
    widget.application.editorTheme.load();
    unawaited(_initializeDocumentOpening());
  }

  Future<void> _initializeDocumentOpening() async {
    try {
      final path = widget.initialDocumentPath;
      if (path != null) {
        await _openExternalBooklet(path);
      }
      await _openFileService.listen(
        _openExternalBooklet,
        onError: _showOpenError,
      );
    } finally {
      if (mounted) {
        setState(() => _checkingInitialDocument = false);
      }
    }
  }

  Future<void> _openExternalBooklet(String path) async {
    if (Platform.isAndroid || widget.application.screen == AppScreen.startup) {
      setState(() => _openingDocuments++);
      try {
        await widget.application.openBookletAtPath(path);
      } catch (_) {
        _showOpenError();
      } finally {
        if (mounted) {
          setState(() => _openingDocuments--);
        }
      }
    } else {
      await _windowManagerService.openDocumentInNewWindow(path);
    }
  }

  void _showOpenError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (mounted && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open booklet. Choose a valid .booklet file.',
            ),
          ),
        );
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openBookletFromStartup() async {
    await widget.application.openBooklet();
  }

  Future<void> _openLegacyBooklet() async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Open booklet package',
    );
    if (path == null) return;
    try {
      await widget.application.openBookletAtPath(path);
    } catch (_) {
      _showOpenError();
    }
  }

  Future<void> _createBooklet() async {
    widget.application.createBooklet();
    await widget.application.editorController.saveBookletAs();
  }

  Future<void> _openBookletFromMenu() async {
    if (widget.application.screen == AppScreen.startup) {
      await _openBookletFromStartup();
    } else {
      await widget.application.editorController.openBooklet();
    }
  }

  void _openInNewWindow() {
    unawaited(_windowManagerService.openDocumentInNewWindow(null));
  }

  @override
  void didChangePlatformBrightness() {
    widget.application.documentSettingsController.updateSystemBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(widget.application.editorController.flushAutoSave());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.application.dispose();
    super.dispose();
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
        final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

        final isDesktopFileMenu = Platform.isMacOS || Platform.isLinux;
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
          home: isDesktopFileMenu
              ? PlatformMenuBar(
                  menus: [
                    PlatformMenu(
                      label: 'File',
                      menus: [
                        PlatformMenuItemGroup(
                          members: [
                            PlatformMenuItem(
                              label: 'Open…',
                              onSelected: _openBookletFromMenu,
                            ),
                            PlatformMenuItem(
                              label: 'Open older folder package…',
                              onSelected: _openLegacyBooklet,
                            ),
                            PlatformMenuItem(
                              label: 'Save',
                              onSelected: () => widget
                                  .application
                                  .editorController
                                  .saveBooklet(),
                            ),
                            PlatformMenuItem(
                              label: 'Save As…',
                              onSelected: () => widget
                                  .application
                                  .editorController
                                  .saveBookletAs(),
                            ),
                          ],
                        ),
                        PlatformMenuItemGroup(
                          members: [
                            PlatformMenuItem(
                              label: 'Open in New Window',
                              onSelected: _openInNewWindow,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  child: _buildHome(),
                )
              : _buildHome(),
        );
      },
    );
  }

  Future<void> _openAndroidBooklet() async {
    final path = await _openFileService.pickAndroidBooklet();
    if (path != null) await widget.application.openBookletAtPath(path);
  }

  Widget _buildHome() => Platform.isAndroid
      ? ReaderShell(
          application: widget.application,
          onOpen: _openAndroidBooklet,
        )
      : _checkingInitialDocument || _openingDocuments > 0
      ? const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Opening booklet…'),
              ],
            ),
          ),
        )
      : Scaffold(
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
                        child: MainView(
                          key: _bookletEditorKey,
                          controller: widget.application.editorController,
                          onOpenInNewWindow: _openInNewWindow,
                        ),
                      ),
                    ),
                    if (widget.application.screen == AppScreen.startup)
                      StartBooklet(
                        onCreateNew: _createBooklet,
                        onOpenExisting: _openBookletFromStartup,
                        onOpenRecent: _openExternalBooklet,
                        onOpenLegacy: _openLegacyBooklet,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
}
