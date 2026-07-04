import 'package:flutter/material.dart';
import 'package:novella/core/navigation/m3e_center_reveal_route.dart';
import 'package:novella/features/main_page.dart';

Route<void> createMainPageRevealRoute() {
  return createM3ECenterRevealRoute<void>(builder: (_) => const MainPage());
}
