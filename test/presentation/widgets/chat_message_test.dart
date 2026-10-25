import 'package:flutter/widgets.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/presentation/theme/omarchy_markdown.dart';
import 'package:clayton_agent/presentation/widgets/chat_message.dart';

import '../../support/omarchy_test_app.dart';

void main() {
  testWidgets('renders user and assistant messages', (tester) async {
    await tester.pumpWidget(
      wrapInOmarchy(
        const SizedBox(
          width: 600,
          child: Column(
            children: [
              ChatMessage(isUser: true, text: 'Hola'),
              ChatMessage(
                isUser: false,
                text: '## Título\n\n```dart\nfinal x = 1;\n```',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('vos'), findsOneWidget);
    expect(find.text('clayton'), findsOneWidget);
    expect(find.textContaining('Hola'), findsOneWidget);
    expect(find.textContaining('Título'), findsWidgets);
    expect(find.byType(HighlightView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stabilizes an unclosed code fence while streaming', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapInOmarchy(
        const SizedBox(
          width: 600,
          child: ChatMessage(
            isUser: false,
            isStreaming: true,
            text: 'Texto\n```dart\nfinal x = 1;',
          ),
        ),
      ),
    );

    expect(find.byType(HighlightView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the omarchy foreground for markdown text and tables', (
    tester,
  ) async {
    late MarkdownStyleSheet sheet;
    await tester.pumpWidget(
      wrapInOmarchy(
        Builder(
          builder: (context) {
            sheet = omarchyMarkdownStyleSheet(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final colors = testOmarchyTheme.colors;
    expect(sheet.p?.color, colors.foreground);
    expect(sheet.strong?.color, colors.foreground);
    expect(sheet.listBullet?.color, colors.foreground);
    expect(sheet.tableHead?.color, colors.foreground);
    expect(sheet.tableBody?.color, colors.foreground);
    expect(sheet.tableBorder?.top.color, colors.border);
  });

  testWidgets('renders table cell text with the omarchy foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapInOmarchy(
        const SizedBox(
          width: 600,
          child: ChatMessage(
            isUser: false,
            text: '| A | B |\n| --- | --- |\n| Celda | Otra |',
          ),
        ),
      ),
    );

    final color = DefaultTextStyle.of(tester.element(find.text('Celda')))
        .style
        .color;
    expect(color, testOmarchyTheme.colors.foreground);
    expect(tester.takeException(), isNull);
  });
}
