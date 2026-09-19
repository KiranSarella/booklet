
import 'package:flutter/foundation.dart';

enum AppScreen { startup, editor }

class App extends ChangeNotifier {
	AppScreen _screen = AppScreen.startup;

	AppScreen get screen => _screen;

	void createBooklet() {
		_showEditor();
	}

	void openBooklet() {
		_showEditor();
	}

	void _showEditor() {
		if (_screen == AppScreen.editor) {
			return;
		}

		_screen = AppScreen.editor;
		notifyListeners();
	}
}