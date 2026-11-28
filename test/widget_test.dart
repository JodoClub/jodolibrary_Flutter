import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jodo_library/main.dart';
import 'package:jodo_library/models/app_models.dart';
import 'package:jodo_library/screens/mobile_screen.dart';
import 'package:jodo_library/utils/password_helper.dart';

void main() {
  testWidgets('App smoke test loads welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const JodoApp());
    expect(find.text('Continue with Google (Student)'), findsOneWidget);
    expect(find.text('Continue with Google (Library Owner)'), findsOneWidget);
    expect(find.textContaining('Login with Mobile & Password'), findsOneWidget);
  });

  test('PasswordHelper enforces strong password policy', () {
    expect(PasswordHelper.validateStrongPassword(''), isNotNull);
    expect(PasswordHelper.validateStrongPassword('Short1!'), isNotNull);
    expect(PasswordHelper.validateStrongPassword('alllowercase1!'), isNotNull);
    expect(PasswordHelper.validateStrongPassword('ALLUPPERCASE1!'), isNotNull);
    expect(PasswordHelper.validateStrongPassword('NoDigitsHere!'), isNotNull);
    expect(PasswordHelper.validateStrongPassword('NoSpecial123'), isNotNull);
    expect(PasswordHelper.validateStrongPassword('Jodo@2026!'), isNull);
  });

  testWidgets('MobileScreen shows password field and Forgot Password recovery popup', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileScreen(
          role: UserRole.student,
          onBack: () {},
          onLoginSuccess: (_) {},
        ),
      ),
    );

    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Login with Google'), findsOneWidget);
    expect(find.text('Enquiry / Contact Us'), findsOneWidget);
    expect(find.textContaining('Settings'), findsOneWidget);
  });
}
