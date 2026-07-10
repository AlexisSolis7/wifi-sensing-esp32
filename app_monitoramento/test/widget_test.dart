import 'package:app_monitoramento/modules/home/home_controller.dart';
import 'package:app_monitoramento/modules/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('mostra tela inicial do monitoramento', (tester) async {
    Get.testMode = true;
    Get.put(HomeController(autoConnect: false));

    await tester.pumpWidget(const GetMaterialApp(home: HomeView()));

    expect(find.text('wifi_sensing'), findsOneWidget);
    expect(find.text('Gateway WebSocket'), findsOneWidget);
    expect(find.text('Sem alerta ativo'), findsOneWidget);

    Get.reset();
  });
}
