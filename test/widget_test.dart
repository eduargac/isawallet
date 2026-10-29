import 'package:flutter_test/flutter_test.dart';

import 'package:isawallet/main.dart';

void main() {
  testWidgets('isaWallet app loads smoke test', (WidgetTester tester) async {
    // Construir nuestra app y disparar un frame
    await tester.pumpWidget(const IsaWalletApp());

    // Verificar que el título de la aplicación sea visible
    expect(find.text('isaWallet'), findsOneWidget);
  });
}
