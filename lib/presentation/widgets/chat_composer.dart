import 'package:flutter_omarchy/flutter_omarchy.dart';

/// Barra de entrada de preguntas del chat.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.isGenerating,
    required this.onSend,
  });

  /// Controlador del texto de la pregunta.
  final TextEditingController controller;

  /// Indica si el modelo está generando una respuesta.
  final bool isGenerating;

  /// Envía la pregunta actual.
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = OmarchyTheme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: OmarchyTextInput(
        key: const Key('chat-input'),
        controller: controller,
        maxLines: 1,
        leading: Text(
          '>',
          style: theme.text.bold.copyWith(color: theme.colors.bright.green),
        ),
        placeholder: const Text('Preguntale al contexto indexado…'),
        onSubmitted: (_) {
          if (!isGenerating) onSend();
        },
        trailing: OmarchyButton(
          key: const Key('chat-send'),
          style: const OmarchyButtonStyle.filled(AnsiColor.blue),
          onPressed: isGenerating ? null : onSend,
          child: isGenerating
              ? const OmarchyLoader(size: 16)
              : const Icon(OmarchyIcons.codSend, size: 16),
        ),
      ),
    );
  }
}
