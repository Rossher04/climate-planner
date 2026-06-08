import 'package:flutter_test/flutter_test.dart';

import 'package:climate/main.dart';
import 'package:climate/services/api_service.dart';

void main() {
  testWidgets('Climate opens the login screen when there is no session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ClimateApp(apiService: ApiService()));

    expect(find.text('Climate'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Recuperar contrasena'), findsOneWidget);
  });
}
