import 'package:flutter/material.dart';




class FontSizes {
  static const extraSmall = 14.0;
  static const small = 16.0;
  static const medium = 18.0;
  static const large = 20.0;
  static const extraLarge = 24.0;
  static const doubleExtraLarge = 26.0;

}

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    background: Color(0xffffffff),
    primary: Color(0xff3369FF),
      secondary: Color(0xffffff)
  ),
  textTheme: TextTheme(
      titleLarge: TextStyle(color: Color(0xff000000),),
      titleSmall: TextStyle(color: Color(0xff000000),),

      bodyMedium: TextStyle(color: Color(0xffEEEEEE),
        fontSize: FontSizes.small,
      ),
      bodySmall: TextStyle(
        color: Color(0xff000000),
        fontSize: FontSizes.small,
      )

  ),
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
        background: Color(0xff000000),
        primary: Color(0xff3369FF),
        secondary: Color(0xffffff)
    ),
  textTheme: TextTheme(
    titleLarge: TextStyle(color: Color(0xffEEEEEE),),
    titleSmall: TextStyle(color: Color(0xff000000),),
    bodyMedium: TextStyle(color: Color(0xffEEEEEE),
                          fontSize: FontSizes.small,
    ),
    bodySmall: TextStyle(
      color: Color(0xff000000),
      fontSize: FontSizes.small,
    )

  ),

);