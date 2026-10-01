import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/projects/presentation/project_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  final token = await ApiClient.getToken();
  final bool isAuthenticated = token != null && token.isNotEmpty;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(RoomlystApp(initialAuthenticated: isAuthenticated));
}

class RoomlystApp extends StatelessWidget {
  final bool initialAuthenticated;
  const RoomlystApp({super.key, this.initialAuthenticated = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: initialAuthenticated ? const ProjectListScreen() : const LoginScreen(),
    );
  }
}
