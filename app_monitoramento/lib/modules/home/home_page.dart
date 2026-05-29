import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Sensing')),
      body: Center(
        child: Obx(
          () => Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(color: controller.statusAlarme.value ? Colors.red : Colors.green),
            child: Center(
              child: Text(controller.statusAlarme.value ? 'MOVIMENTO!' : 'Aguardando...', style: const TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
        ),
      ),
    );
  }
}
