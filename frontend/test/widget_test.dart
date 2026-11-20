import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/main.dart';

void main() {
  testWidgets('FinanceApp smoke test - shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanceApp());
    expect(find.text('Catatan Keuangan'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);
  });
}
