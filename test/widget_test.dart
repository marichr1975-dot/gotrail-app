import 'package:flutter_test/flutter_test.dart';
import 'package:gotr_ai_2_0/main.dart';

void main() {
  testWidgets('GoTr-AI 2.0 si avvia', (WidgetTester tester) async {
    await tester.pumpWidget(const GoTrAiApp());
    expect(find.byType(GoTrAiApp), findsOneWidget);
  });
}
