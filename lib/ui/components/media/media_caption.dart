import 'media_source_link.dart';
import 'media_url_dialog.dart';

import 'package:booklet/ui/components/component_state.dart';
import 'package:flutter/material.dart';

/// The caption remains editable while selected, including when it is empty.
class MediaCaption extends StatelessWidget {
  const MediaCaption({
    super.key,
    required this.state,
    required this.isSelected,
    required this.onSelect,
    required this.child,
    this.isReadOnly = false,
    this.sourceUrl,
  });

  final CaptionedMediaComponentState state;
  final bool isSelected;
  final bool isReadOnly;
  final VoidCallback onSelect;
  final Widget child;
  final String? sourceUrl;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.grey, fontSize: 13);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        if (isSelected && isMediaUrl(sourceUrl ?? ''))
          MediaSourceLink(url: sourceUrl!),
        ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            if (!isSelected && state.caption.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: isSelected
                    ? Focus(
                        onFocusChange: (focused) => state.isFocused = focused,
                        child: TextField(
                          controller: state.captionController,
                          readOnly: isReadOnly,
                          onTap: onSelect,
                          textAlign: TextAlign.center,
                          minLines: 1,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: style,
                          decoration: const InputDecoration(
                            hintText: 'Add caption',
                            hintStyle: style,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: onSelect,
                        child: Text(
                          state.caption,
                          textAlign: TextAlign.center,
                          style: style,
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }
}
