import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:booklet/ui/editor/booklet_editor/booklet_editor.dart';
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
  final _optionsDockKey = GlobalKey<OptionsDockState>();
  final _bookletEditorKey = GlobalKey<BookletEditorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        backgroundColor: const Color(0xFFF3F6FF),
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
                      child: BookletEditor(key: _bookletEditorKey),
                    ),
                  ),
                  Positioned.fill(
                    child: OptionsDock(
                      key: _optionsDockKey,
                      onComponentSelected: (type) {
                        _bookletEditorKey.currentState
                            ?.addComponentBelowSelected(type);
                      },
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
