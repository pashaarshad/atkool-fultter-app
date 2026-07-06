import 'package:flutter_test/flutter_test.dart';
import 'package:school_connect/main.dart';

void main() {
  testWidgets('App should load splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ATKoolApp());
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
