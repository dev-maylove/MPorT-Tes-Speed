import 'package:flutter_test/flutter_test.dart';

import 'package:mport_test_speed/main.dart';

void main() {
  testWidgets('MporTApp loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MporTApp());
    await tester.pump();

    expect(find.textContaining('MPorT'), findsWidgets);
  });
}
