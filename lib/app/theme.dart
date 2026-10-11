import 'package:flutter/material.dart';

abstract final class AppColors {
  static const verde = Color(0xFF16845B);
  static const verdeEscuro = Color(0xFF15553B);
  static const verdeClaro = Color(0xFFE8F5EE);
  static const verdePastel = Color(0xFFF1F8F3);
  static const borda = Color(0xFFE3EBE6);
  static const erro = Color(0xFFB93838);
  static const branco = Color(0xFFFFFFFF);
  static const fundo = Color(0xFFF6FAF7);
  static const texto = Color(0xFF153B31);
  static const textoSuave = Color(0xFF7D8985);
  static const estrela = Color(0xFFFFC107);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadii {
  static const field = 14.0;
  static const card = 18.0;
  static const panel = 22.0;
  static const pill = 100.0;
}

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.verde,
      primary: AppColors.verde,
      secondary: AppColors.verdeEscuro,
      error: AppColors.erro,
      surface: AppColors.branco,
    ),
    scaffoldBackgroundColor: AppColors.fundo,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: AppColors.texto,
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: AppColors.texto,
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: AppColors.texto,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: AppColors.texto, height: 1.4),
      bodySmall: TextStyle(color: AppColors.textoSuave, height: 1.35),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.branco,
      foregroundColor: AppColors.texto,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.texto,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.branco,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: AppColors.textoSuave),
      prefixIconColor: AppColors.textoSuave,
      suffixIconColor: AppColors.textoSuave,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.verde, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB3261E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.branco,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: const Color(0x10153B31),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: const BorderSide(color: AppColors.borda),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.verdeClaro,
      elevation: 4,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
