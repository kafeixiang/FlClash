import 'package:fl_clash/manager/status_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('shows a message until its duration expires', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        wrapInProviderScope: true,
        child: StatusManager(child: SizedBox()),
      ),
    );
    final state = tester.state<StatusManagerState>(find.byType(StatusManager));
    state.message('hello');
    await tester.pump();

    expect(find.text('hello'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('hello'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('buffers the next message until the current one expires', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        wrapInProviderScope: true,
        child: StatusManager(child: SizedBox()),
      ),
    );
    final state = tester.state<StatusManagerState>(find.byType(StatusManager));
    state.message('first');
    state.message('second');
    await tester.pump();

    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('second'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('runs the action and dismisses the message when tapped', (
    tester,
  ) async {
    var ran = false;
    await tester.pumpWidget(
      const TestApp(
        wrapInProviderScope: true,
        child: StatusManager(child: SizedBox()),
      ),
    );
    final state = tester.state<StatusManagerState>(find.byType(StatusManager));
    state.message(
      'restart needed',
      actionState: MessageActionState(
        actionText: 'restart',
        action: () => ran = true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('restart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(ran, isTrue);
    expect(find.text('restart needed'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('swipe dismiss removes the message', (tester) async {
    await tester.pumpWidget(
      const TestApp(
        wrapInProviderScope: true,
        child: StatusManager(child: SizedBox()),
      ),
    );
    final state = tester.state<StatusManagerState>(find.byType(StatusManager));
    state.message('swipe me');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.drag(find.byType(Dismissible), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('swipe me'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
