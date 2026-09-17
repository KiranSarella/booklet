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
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartupChoice();
    });
  }

  Future<void> _showStartupChoice() async {
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final choice = await showDialog<_StartupChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Start booklet'),
        content: const Text('Open an existing booklet or create a new one.'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_StartupChoice.newBooklet),
            icon: const Icon(Icons.add),
            label: const Text('Create new'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pop(_StartupChoice.openExisting),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Open existing'),
          ),
        ],
      ),
    );

    if (choice == _StartupChoice.openExisting && mounted) {
      await _openBooklet();
    }
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

  Future<void> _saveBooklet() async {
    final editor = _bookletEditorKey.currentState;
    if (editor == null) {
      return;
    }
    if (!editor.hasOpenedBooklet) {
      _showMessage('Opening save dialog...');
    }
    try {
      final saved = await editor.saveBooklet();
      if (saved) {
        _showMessage('Booklet saved');
      }
    } catch (error) {
      _showMessage('Could not save booklet: $error');
    }
  }

  Future<void> _openBooklet() async {
    _showMessage('Opening file dialog...');
    try {
      final opened =
          await _bookletEditorKey.currentState?.openBooklet() ?? false;
      if (opened) {
        _showMessage('Booklet opened');
      }
    } catch (error) {
      _showMessage('Could not open booklet: $error');
    }
  }

  void _showMessage(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
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
                    right: 102,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          tooltip: 'Open booklet',
                          icon: Icons.folder_open_outlined,
                          onPressed: _openBooklet,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          tooltip: 'Save booklet',
                          icon: Icons.save_outlined,
                          onPressed: _saveBooklet,
                        ),
                        const SizedBox(width: 8),
                        _ActionButton(
                          tooltip: 'Edit theme',
                          icon: Icons.palette_outlined,
                          onPressed: _showThemeEditor,
                        ),
                      ],
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

enum _StartupChoice { newBooklet, openExisting }

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          constraints: const BoxConstraints.tightFor(width: 52, height: 44),
          padding: EdgeInsets.zero,
          tooltip: tooltip,
        ),
      ),
    );
  }
}
