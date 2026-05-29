import 'package:get/get.dart';

import '../modules/home/home_binding.dart';
import '../modules/home/home_page.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [GetPage(name: AppRoutes.HOME, page: () => const HomeView(), binding: HomeBinding())];
}
