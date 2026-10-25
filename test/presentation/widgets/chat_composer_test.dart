import 'package:flutter_omarchy/flutter_omarchy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clayton_agent/presentation/widgets/chat_composer.dart';

import '../../support/omarchy_test_app.dart';

void main() {
  testWidgets('submits the typed text', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sent = 0;

    await tester.pumpWidget(
      wrapInOmarchy(
        SizedBox(
          width: 600,
          child: ChatComposer(
            controller: controller,
            isGenerating: false,
            onSend: () => sent++,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'Hola');
    await tester.tap(find.byKey(const Key('chat-send')));
    expect(sent, 1);
  });

  testWidgets('submits with Enter when idle', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sent = 0;

    await tester.pumpWidget(
      wrapInOmarchy(
        SizedBox(
          width: 600,
          child: ChatComposer(
            controller: controller,
            isGenerating: false,
            onSend: () => sent++,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(EditableText), 'Hola');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(sent, 1);
  });

  testWidgets('does not submit while generating', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sent = 0;

    await tester.pumpWidget(
      wrapInOmarchy(
        SizedBox(
          width: 600,
          child: ChatComposer(
            controller: controller,
            isGenerating: true,
            onSend: () => sent++,
          ),
        ),
      ),
    );

    final send = tester.widget<OmarchyButton>(
      find.byKey(const Key('chat-send')),
    );
    expect(send.onPressed, isNull);
    await tester.enterText(find.byType(EditableText), 'Hola');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(sent, 0);
  });
}
