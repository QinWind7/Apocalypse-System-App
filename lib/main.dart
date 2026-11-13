import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/system_home_screen.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 沉浸式全屏：隐藏状态栏与底部导航栏，向上滑动时短暂出现后自动隐藏。
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      // 关闭系统自动加的导航栏/状态栏遮罩，避免底部出现灰白底边。
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // 初始化通知插件，并恢复已保存的每日唤醒提醒。
  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance.rescheduleSaved();
  } catch (_) {
    // 通知初始化失败不应阻塞 App 启动。
  }

  runApp(const TianqiSystemApp());
}

class TianqiSystemApp extends StatelessWidget {
  const TianqiSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '天命系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        splashFactory: NoSplash.splashFactory,
      ),
      home: const SystemHomeScreen(),
    );
  }
}
