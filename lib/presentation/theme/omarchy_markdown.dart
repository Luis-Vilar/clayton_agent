import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';
import 'package:markdown/markdown.dart' as md;

/// Hoja de estilos Markdown derivada de la paleta Omarchy activa.
MarkdownStyleSheet omarchyMarkdownStyleSheet(BuildContext context) {
  final theme = OmarchyTheme.of(context);
  final bright = theme.colors.bright;

  return MarkdownStyleSheet(
    p: theme.text.normal,
    a: theme.text.normal.copyWith(
      color: bright.blue,
      decoration: TextDecoration.underline,
    ),
    em: theme.text.italic,
    strong: theme.text.bold,
    del: theme.text.normal.copyWith(decoration: TextDecoration.lineThrough),
    code: theme.text.normal.copyWith(
      color: bright.green,
      backgroundColor: theme.colors.normal.black,
    ),
    h1: theme.text.bold.copyWith(color: bright.magenta, fontSize: 22),
    h2: theme.text.bold.copyWith(color: bright.magenta, fontSize: 20),
    h3: theme.text.bold.copyWith(color: bright.magenta, fontSize: 18),
    h4: theme.text.bold.copyWith(color: bright.magenta, fontSize: 16),
    h5: theme.text.bold.copyWith(color: bright.magenta, fontSize: 15),
    h6: theme.text.bold.copyWith(color: bright.magenta, fontSize: 14),
    blockquote: theme.text.italic.copyWith(color: bright.yellow),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: bright.yellow, width: 2)),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    listBullet: theme.text.normal,
    blockSpacing: 8,
    listIndent: 18,
  );
}

/// Tema de resaltado de sintaxis para los bloques de código.
Map<String, TextStyle> omarchyCodeTheme(BuildContext context) {
  final theme = OmarchyTheme.of(context);
  final bright = theme.colors.bright;

  return {
    'root': theme.text.normal.copyWith(
      backgroundColor: theme.colors.normal.black,
    ),
    'keyword': theme.text.bold.copyWith(color: bright.magenta),
    'string': theme.text.normal.copyWith(color: bright.green),
    'comment': theme.text.italic.copyWith(color: bright.black),
    'number': theme.text.normal.copyWith(color: bright.yellow),
    'built_in': theme.text.normal.copyWith(color: bright.cyan),
    'literal': theme.text.normal.copyWith(color: bright.yellow),
    'type': theme.text.normal.copyWith(color: bright.cyan),
    'title': theme.text.bold.copyWith(color: bright.blue),
    'attr': theme.text.normal.copyWith(color: bright.yellow),
    'variable': theme.text.normal.copyWith(color: bright.blue),
    'selector-tag': theme.text.normal.copyWith(color: bright.magenta),
    'selector-id': theme.text.normal.copyWith(color: bright.magenta),
    'selector-class': theme.text.normal.copyWith(color: bright.yellow),
    'meta': theme.text.normal.copyWith(color: bright.black),
    'tag': theme.text.normal.copyWith(color: bright.magenta),
  };
}

/// Builder de bloques de código con la estética Omarchy.
class OmarchyCodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final theme = OmarchyTheme.of(context);
    var language = 'plaintext';
    final className = element.attributes['class'];
    if (className != null && className.startsWith('language-')) {
      language = className.substring(9);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colors.normal.black,
        border: Border(
          left: BorderSide(color: theme.colors.bright.magenta, width: 2),
        ),
      ),
      child: HighlightView(
        element.textContent.trim(),
        language: language,
        theme: omarchyCodeTheme(context),
        textStyle: theme.text.normal,
      ),
    );
  }
}
