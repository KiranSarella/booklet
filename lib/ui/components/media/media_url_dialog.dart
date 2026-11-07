import 'package:flutter/material.dart';

bool isMediaUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
}

Future<String?> showMediaUrlDialog(BuildContext context, String kind) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        void submit() {
          if (formKey.currentState!.validate()) {
            Navigator.pop(context, controller.text.trim());
          }
        }

        return AlertDialog(
          title: Text('Add $kind URL'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL',
                  helperText: kind == 'video'
                      ? 'YouTube, Instagram, Vimeo, shared storage, or direct video URL.'
                      : 'Use a direct link to an image file.',
                ),
                validator: (value) => isMediaUrl(value?.trim() ?? '')
                    ? null
                    : 'Enter a valid HTTP or HTTPS URL.',
                onFieldSubmitted: (_) => submit(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: submit, child: const Text('Add')),
          ],
        );
      },
    );
  } finally {
    // Wait for the dialog route's closing animation before disposing its field.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }
}
