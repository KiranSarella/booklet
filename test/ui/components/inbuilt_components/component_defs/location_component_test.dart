import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:booklet/storage/booklet_file.dart';
import 'package:booklet/business/page_content.dart';
import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/application/document_settings_controller.dart';
import 'package:booklet/ui/detail/editor/component_minimap_preview.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:booklet/ui/components/component_box.dart';
import 'package:booklet/ui/components/component_snapshot.dart';
import 'package:booklet/ui/components/inbuilt_components/component_defs/location_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  test(
    'location name and coordinates persist when a booklet page is reopened',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'location-persistence-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final component = LocationComponent(id: 'saved-location');
      addTearDown(component.dispose);
      component.state.restore({
        'name': 'Library',
        'latitude': 0,
        'longitude': -180,
      });
      final page = PageContent(
        id: 'location-page',
        title: 'Location',
        components: [ComponentBox(component: component)],
      );
      await BookletFile.savePage(directory.path, page);
      final settings = DocumentSettingsController();
      final theme = PageSettingsController(settings);
      addTearDown(theme.dispose);
      addTearDown(settings.dispose);
      final loaded = await BookletFile.loadPage(directory.path, page.id, theme);
      final restored = loaded.components.single.component;
      addTearDown(restored.dispose);
      expect(restored.id, component.id);
      expect(restored.output, component.output);
      await BookletFile.savePage(directory.path, loaded);
      final reopened = await BookletFile.loadPage(
        directory.path,
        page.id,
        theme,
      );
      addTearDown(reopened.components.single.component.dispose);
      expect(reopened.components.single.component.output, component.output);
    },
  );

  testWidgets('minimap represents location with a pin icon', (tester) async {
    final component = LocationComponent(id: 'minimap-location');
    addTearDown(component.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 100,
          height: 40,
          child: ComponentMinimapPreview(
            box: ComponentBox(component: component),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
  });

  test('coordinates validate ranges, finite numbers and zero', () {
    final state = LocationComponentState();
    addTearDown(state.dispose);
    for (final invalid in ['NaN', 'Infinity', '91', '-91', 'place']) {
      expect(LocationComponentState.parseCoordinate(invalid, 90), isNull);
    }
    state.restore({'latitude': 0, 'longitude': -180});
    expect(state.hasCoordinates, isTrue);
    state.longitudeController.text = '181';
    expect(state.hasCoordinates, isFalse);
  });

  test('coordinates survive document snapshots and duplication', () {
    final component = LocationComponent(id: 'location');
    addTearDown(component.dispose);
    component.state.restore({
      'name': 'Library',
      'latitude': 13.0827,
      'longitude': 80.2707,
    });
    final snapshot = ComponentSnapshot.capture(
      ComponentBox(component: component),
    );
    final restored = ComponentSnapshot.fromJson(snapshot.toJson())
        .instantiate();
    addTearDown(restored.component.dispose);
    expect(restored.component.output, component.output);
  });

  test('map links target coordinates on each platform', () {
    expect(
      LocationComponentView.mapsUri(
        0,
        -180,
        platform: TargetPlatform.android,
      ).scheme,
      'geo',
    );
    expect(
      LocationComponentView.mapsUri(13, 80, platform: TargetPlatform.iOS).host,
      'maps.apple.com',
    );
    expect(
      LocationComponentView.mapsUri(13, 80).queryParameters['query'],
      '13.0,80.0',
    );
  });

  testWidgets('read-only card has no editor and empty map action is disabled', (
    tester,
  ) async {
    final state = LocationComponentState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationComponentView(
            state: state,
            isSelected: true,
            readOnly: true,
            onSelect: () {},
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    state.restore({'latitude': 13, 'longitude': 80});
    await tester.pump();
    expect(find.text('13.0, 80.0'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
