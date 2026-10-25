import 'package:flutter/widgets.dart';
import 'package:flutter_omarchy/flutter_omarchy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/presentation/widgets/knowledge_panel.dart';
import '../../support/omarchy_test_app.dart';

void main() {
  testWidgets('shows the empty state when there are no files', (tester) async {
    await tester.pumpWidget(wrapInOmarchy(const KnowledgePanel(
      files: [],
      isBusy: false,
      onPickFiles: _noop,
      onPickDirectory: _noop,
      onClear: _noop,
    )));

    expect(find.text('Conocimiento local'), findsOneWidget);
    expect(
      find.text('No hay documentos cargados.\nAgrega archivos .md o carpetas.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ellipsizes long document names', (tester) async {
    await tester.pumpWidget(wrapInOmarchy(const KnowledgePanel(
      files: ['un-nombre-de-archivo-extraordinariamente-largo.md'],
      isBusy: false,
      onPickFiles: _noop,
      onPickDirectory: _noop,
      onClear: _noop,
    )));

    final name = tester.widget<Text>(
      find.text('un-nombre-de-archivo-extraordinariamente-largo.md'),
    );
    expect(name.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables actions while busy', (tester) async {
    await tester.pumpWidget(wrapInOmarchy(const KnowledgePanel(
      files: [],
      isBusy: true,
      onPickFiles: _noop,
      onPickDirectory: _noop,
      onClear: _noop,
    )));

    final button = tester.widget<OmarchyButton>(
      find.widgetWithText(OmarchyButton, 'Subir archivo(s)'),
    );
    expect(button.onPressed, isNull);
  });
}

void _noop() {}
