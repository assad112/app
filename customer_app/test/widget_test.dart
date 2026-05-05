import 'package:customer_app/app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('customer app renders splash flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CustomerApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(CustomerApp), findsOneWidget);
  });
}
