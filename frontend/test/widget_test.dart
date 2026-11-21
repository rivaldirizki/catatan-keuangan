import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/main.dart';

void main() {
  testWidgets('FinanceApp smoke test - shows splash screen with Dompet Linc', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanceApp());
    expect(find.text('Dompet Linc'), findsOneWidget);
  });
}
