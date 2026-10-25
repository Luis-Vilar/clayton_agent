import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';

import '../theme/omarchy_markdown.dart';

/// Un mensaje del historial de chat.
class ChatMessage extends StatelessWidget {
  const ChatMessage({
    super.key,
    required this.isUser,
    required this.text,
    this.isStreaming = false,
  });

  /// Indica si el mensaje fue escrito por el usuario.
  final bool isUser;

  /// Contenido del mensaje; Markdown para el asistente.
  final String text;

  /// Indica si el mensaje todavía se está generando.
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = OmarchyTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isUser ? 'vos' : 'clayton',
          style: theme.text.bold.copyWith(
            fontSize: 10,
            letterSpacing: 1,
            color: isUser
                ? theme.colors.bright.green
                : theme.colors.bright.cyan,
          ),
        ),
        const SizedBox(height: 4),
        if (isUser)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colors.normal.black,
              border: Border.all(color: theme.colors.border),
            ),
            child: Text(text, style: theme.text.normal),
          )
        else
          MarkdownBody(
            data: isStreaming ? _estabilizarMarkdown(text) : text,
            selectable: !isStreaming,
            styleSheet: omarchyMarkdownStyleSheet(context),
            builders: {'code': OmarchyCodeBlockBuilder()},
          ),
      ],
    );
  }
}

/// Cierra temporalmente un bloque de código abierto mientras llega el stream.
String _estabilizarMarkdown(String textoIncompleto) {
  if (textoIncompleto.isEmpty) return '';

  final conteoComillas = '```'.allMatches(textoIncompleto).length;
  if (conteoComillas % 2 != 0) {
    return '$textoIncompleto\n```';
  }

  return textoIncompleto;
}
