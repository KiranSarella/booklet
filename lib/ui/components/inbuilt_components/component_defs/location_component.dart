import 'package:booklet/application/page_settings_controller.dart';
import 'package:booklet/business/components_business/component_def.dart';
import 'package:booklet/business/components_business/inbuilt_components/inbuit_components_definations.dart';
import 'package:booklet/ui/components/component.dart';
import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationComponent implements Component {
  LocationComponent({required this.id});
  @override
  final String id;
  @override
  final LocationComponentState state = LocationComponentState();
  @override
  ComponentDef get def => LocationComponentDef();
  @override
  Object get output => state.output;
  @override
  List<dynamic>? get textDelta => null;
  @override
  void dispose() => state.dispose();
  @override
  void initialize({List<dynamic>? delta}) {
    // Recover coordinate pairs entered into the original dummy text block.
    final text = delta
        ?.map((op) => op is Map ? op['insert'] ?? '' : '')
        .join()
        .trim();
    final parts = text?.split(',');
    if (parts != null &&
        parts.length == 2 &&
        LocationComponentState.parseCoordinate(parts[0], 90) != null &&
        LocationComponentState.parseCoordinate(parts[1], 180) != null) {
      state.restore({
        'latitude': parts[0].trim(),
        'longitude': parts[1].trim(),
      });
    }
  }

  @override
  Widget buildUI({
    required PageSettingsController theme,
    required ComponentState componentState,
    required bool isSelected,
    required VoidCallback onSelect,
    required VoidCallback onCreateBelow,
  }) => LocationComponentView(
    state: state,
    isSelected: isSelected,
    readOnly: theme.documentSettingsController.isReadOnly,
    onSelect: onSelect,
  );
}

class LocationComponentView extends StatelessWidget {
  const LocationComponentView({
    super.key,
    required this.state,
    required this.isSelected,
    required this.readOnly,
    required this.onSelect,
  });
  final LocationComponentState state;
  final bool isSelected;
  final bool readOnly;
  final VoidCallback onSelect;

  static Uri mapsUri(
    double latitude,
    double longitude, {
    TargetPlatform? platform,
  }) {
    final point = '$latitude,$longitude';
    if (!kIsWeb && platform == TargetPlatform.android) {
      return Uri.parse('geo:$point?q=$point');
    }
    if (!kIsWeb &&
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS)) {
      return Uri.https('maps.apple.com', '/', {'ll': point, 'q': point});
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': point,
    });
  }

  Future<void> _open(BuildContext context) async {
    if (!state.hasCoordinates) return;
    final latitude = state.latitude!;
    final longitude = state.longitude!;
    final native = mapsUri(
      latitude,
      longitude,
      platform: defaultTargetPlatform,
    );
    final fallback = mapsUri(latitude, longitude);
    for (final uri in {native, fallback}) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // Try the web maps fallback if the device has no handler.
      }
    }
    if (context.mounted) {
      _message(
        context,
        'Could not open maps. Copy the coordinates to use them in your map app.',
      );
    }
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: state.coordinates));
      if (context.mounted) _message(context, 'Coordinates copied');
    } catch (_) {
      if (context.mounted) _message(context, 'Could not copy coordinates.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final editing = isSelected && !readOnly;
      return Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? colors.primary : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: colors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: editing
                          ? TextField(
                              controller: state.nameController,
                              decoration: const InputDecoration(
                                labelText: 'Location',
                                hintText: 'Enter a location name',
                              ),
                              onTap: () {
                                state.isFocused = true;
                                onSelect();
                              },
                              onTapOutside: (_) {
                                state.isFocused = false;
                              },
                            )
                          : Text(
                              state.nameController.text.trim().isEmpty
                                  ? 'Location'
                                  : state.nameController.text.trim(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (editing)
                  Focus(
                    onFocusChange: (focused) {
                      state.isFocused = focused;
                      if (focused) onSelect();
                    },
                    child: Column(
                      children: [
                        _field(
                          state.latitudeController,
                          'Latitude',
                          '−90 to 90',
                          90,
                          state.focusNode,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          state.longitudeController,
                          'Longitude',
                          '−180 to 180',
                          180,
                          null,
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    state.hasCoordinates
                        ? state.coordinates
                        : (readOnly
                              ? 'No coordinates saved'
                              : 'Add latitude and longitude'),
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: state.hasCoordinates
                          ? () => _open(context)
                          : null,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Open in Maps'),
                    ),
                    IconButton(
                      onPressed: state.hasCoordinates
                          ? () => _copy(context)
                          : null,
                      tooltip: 'Copy coordinates',
                      icon: const Icon(Icons.copy_outlined, size: 18),
                    ),
                    if (!readOnly && !editing)
                      IconButton(
                        onPressed: onSelect,
                        tooltip: 'Edit coordinates',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    double limit,
    FocusNode? focusNode,
  ) => TextField(
    controller: controller,
    focusNode: focusNode,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      errorText:
          controller.text.isNotEmpty &&
              LocationComponentState.parseCoordinate(controller.text, limit) ==
                  null
          ? 'Enter a number between −${limit.toInt()} and ${limit.toInt()}'
          : null,
    ),
  );
}
