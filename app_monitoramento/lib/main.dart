import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(
    GetMaterialApp(
      title: 'Wi-Fi Sensing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF20212A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7EA2FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF23242E),
        ),
        fontFamily: 'Arial',
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1F2029),
          border: OutlineInputBorder(),
        ),
      ),
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages,
    ),
  );
}
