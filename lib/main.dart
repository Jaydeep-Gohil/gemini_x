import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gemini_x/MyHomePage.dart';
import 'package:gemini_x/onboarding.dart';
import 'package:gemini_x/themeNotifier.dart';
import 'package:gemini_x/themes.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';



void main()async{
  await dotenv.load(fileName: '.env');
  print('DBG main: keyPresent=${dotenv.env['GOOGLE_API_KEY']?.isNotEmpty}');


  runApp(ProviderScope(child: MyApp()));
}


class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context,WidgetRef ref) {

    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      title: 'Flutter Demo',
      theme: lightMode,
      darkTheme: darkMode,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: OnBoarding(),
    );
  }
}
