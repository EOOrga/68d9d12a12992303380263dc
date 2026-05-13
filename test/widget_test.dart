import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:julienne_ops/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigates across operations workstreams', (tester) async {
    final store = OperationsStore(screenshotMode: true);
    await store.load();

    await tester.pumpWidget(OperationsApp(store: store));

    expect(find.byKey(const ValueKey('dashboard-screen')), findsOneWidget);
    expect(find.text('Daily operations status'), findsOneWidget);

    await tester.tap(find.text('Payroll'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('payroll-screen')), findsOneWidget);
    expect(find.text('May payroll closeout'), findsOneWidget);

    await tester.tap(find.text('Rooms'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('facilities-screen')), findsOneWidget);
    expect(find.text('North training room'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-screen')), findsOneWidget);
    expect(find.text('Device storage'), findsOneWidget);
  });

  testWidgets('creates and opens a local payroll record', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = OperationsStore(screenshotMode: false);
    await store.load();

    await tester.pumpWidget(OperationsApp(store: store));
    await tester.tap(find.text('Payroll'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-payroll')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('record-title-field')),
      'Quarter-end payroll',
    );
    await tester.enterText(
      find.byKey(const ValueKey('record-owner-field')),
      'Finance desk',
    );
    await tester.enterText(
      find.byKey(const ValueKey('record-schedule-field')),
      'June 1-15, 2026',
    );
    await tester.enterText(
      find.byKey(const ValueKey('record-metric-field')),
      r'$51,200',
    );
    await tester.enterText(
      find.byKey(const ValueKey('record-summary-field')),
      'Payroll report prepared for supervisor review.',
    );

    await tester.tap(find.byKey(const ValueKey('save-record-button')));
    await tester.pumpAndSettle();

    expect(find.text('Quarter-end payroll'), findsOneWidget);
    await tester.tap(find.text('Quarter-end payroll'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('detail-screen')), findsOneWidget);
    expect(find.text('Finance desk'), findsOneWidget);
    expect(find.text(r'$51,200'), findsOneWidget);
  });
}
