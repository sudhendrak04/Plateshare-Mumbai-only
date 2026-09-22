import 'package:flutter_test/flutter_test.dart';
import 'package:buyer/main.dart';

void main() {
  testWidgets('buyer app shell renders', (tester) async {
    await tester.pumpWidget(const PlateShareBuyerApp());
    expect(find.text('Plate Share'), findsOneWidget);
    expect(find.text('Buyer'), findsOneWidget);
  });
}
