import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomeController extends GetxController {
  final statusAlarme = false.obs;
  late WebSocketChannel channel;

  @override
  void onInit() {
    super.onInit();
    conectarWebSocket();
  }

  void conectarWebSocket() {
    channel = WebSocketChannel.connect(Uri.parse('ws://192.168.4.2:81'));

    channel.stream.listen(
      (mensagem) {
        if (mensagem == "MOVIMENTO_DETECTADO") {
          dispararAlarme();
        }
      },
      // ignore: avoid_print
      onError: (erro) => print("Erro de conexão: $erro"),
    );
  }

  void dispararAlarme() {
    statusAlarme.value = true;

    Future.delayed(const Duration(seconds: 3), () {
      statusAlarme.value = false;
    });
  }

  @override
  void onClose() {
    channel.sink.close();
    super.onClose();
  }
}
