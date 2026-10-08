import 'package:flutter/material.dart';

import '../../presentation/platform_design/adaptive.dart';

class TextEditorResult {
  final String title;
  final String text;
  const TextEditorResult(this.title, this.text);
}

class TextEditorPage extends StatefulWidget {
  final String initialTitle;
  final String initialText;
  const TextEditorPage({super.key, this.initialTitle = '', this.initialText = ''});

  @override
  State<TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<TextEditorPage> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _text = TextEditingController(text: widget.initialText);

  @override
  Widget build(BuildContext context) {
    return AdaptivePage(
      title: 'Text message',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, TextEditorResult(_title.text, _text.text)),
          child: const Text('Done'),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          AdaptiveTextField(controller: _title, placeholder: 'Title (optional)'),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _text,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(hintText: 'Type your message…'),
            ),
          ),
        ]),
      ),
    );
  }
}