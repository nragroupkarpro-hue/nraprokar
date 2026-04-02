import 'package:flutter/material.dart';
import 'package:nra_pro_kar/pages/auth/login_page.dart';
import 'package:nra_pro_kar/pages/dashboard/dashboard_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => LoginPage(),
    dashboard: (context) => DashboardPage(),
  };
}
