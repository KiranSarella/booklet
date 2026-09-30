import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart';

// class _ColorPickerDialog extends StatelessWidget {
//   const _ColorPickerDialog({required this.initialColor});

//   final Color initialColor;

//   static const _colors = [
//     Colors.black,
//     Colors.white,
//     Colors.red,
//     Colors.pink,
//     Colors.orange,
//     Colors.amber,
//     Colors.yellow,
//     Colors.lime,
//     Colors.green,
//     Colors.teal,
//     Colors.cyan,
//     Colors.lightBlue,
//     Colors.blue,
//     Colors.indigo,
//     Colors.purple,
//     Colors.deepPurple,
//     Color(0xFF263238),
//     Color(0xFF455A64),
//     Color(0xFF795548),
//     Color(0xFF607D8B),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Choose color'),
//       content: Wrap(
//         spacing: 10,
//         runSpacing: 10,
//         children: [
//           for (final color in _colors)
//             InkWell(
//               onTap: () => Navigator.of(context).pop(color),
//               borderRadius: BorderRadius.circular(20),
//               child: CircleAvatar(
//                 radius: 17,
//                 backgroundColor: color,
//                 child: color.toARGB32() == initialColor.toARGB32()
//                     ? const Icon(Icons.check, color: Colors.white, size: 18)
//                     : null,
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

  // String _colorValue(Color color) {
  //   return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  // }



class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({super.key, required this.initialColor});

  final Color initialColor;

  @override
  State<ColorPickerDialog> createState() => ColorPickerDialogState();
}

class ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose color'),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: _selectedColor,
          onColorChanged: (color) {
            setState(() => _selectedColor = color);
          },
          paletteType: PaletteType.hsv,
          enableAlpha: false,
          displayThumbColor: true,
          pickerAreaHeightPercent: 0.7,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor),
          child: const Text('Use color'),
        ),
      ],
    );
  }
}