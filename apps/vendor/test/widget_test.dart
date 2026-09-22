import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/main.dart';

void main() {
  testWidgets('vendor app shell renders', (tester) async {
    await tester.pumpWidget(const PlateShareVendorApp());
    expect(find.text('Plate Share'), findsOneWidget);
    expect(find.text('Vendor'), findsOneWidget);
  });
}
