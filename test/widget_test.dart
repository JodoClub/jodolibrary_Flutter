import 'package:flutter_test/flutter_test.dart';
import 'package:jodo_library/main.dart';

void main() {
  testWidgets('App smoke test loads welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const JodoApp());
    expect(find.text('Continue with Google (Student)'), findsOneWidget);
    expect(find.text('Continue with Google (Library Owner)'), findsOneWidget);
  });
}
