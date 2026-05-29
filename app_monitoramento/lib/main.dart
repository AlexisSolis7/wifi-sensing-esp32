import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(GetMaterialApp(title: 'Wi-Fi Sensing', debugShowCheckedModeBanner: false, initialRoute: AppRoutes.HOME, getPages: AppPages.pages));
}
