import 'package:flutter/material.dart';

abstract final class AppColors {
  static const verde = Color(0xFF157A54);
  static const verdeEscuro = Color(0xFF15553B);
  static const verdeClaro = Color(0xFFE8F5EE);
  static const verdePastel = Color(0xFFF1F8F3);
  static const borda = Color(0xFFE3EBE6);
  static const erro = Color(0xFFB93838);
  static const branco = Color(0xFFFFFFFF);
  static const fundo = Color(0xFFF6FAF7);
  static const texto = Color(0xFF153B31);
  static const textoSuave = Color(0xFF65716D);
  static const estrela = Color(0xFFFFC107);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  // Margem lateral do conteúdo móvel, preservada em 20 px.
  static const pageGutter = 20.0;
}

abstract final class AppInsets {
  static const page = EdgeInsets.fromLTRB(
    AppSpace.pageGutter,
    AppSpace.lg,
    AppSpace.pageGutter,
    AppSpace.xxl,
  );
  static const card = EdgeInsets.all(AppSpace.lg);
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
        height: 1.2,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: AppColors.texto,
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: AppColors.texto,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: AppColors.texto, fontSize: 14, height: 1.45),
      bodySmall: TextStyle(
        color: AppColors.textoSuave,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.branco,
      foregroundColor: AppColors.texto,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.texto,
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.branco,
      contentPadding: const EdgeInsets.all(AppSpace.lg),
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
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.verde, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: Color(0xFFB3261E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
      ),
    ),
    chipTheme: const ChipThemeData(shape: StadiumBorder()),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.panel),
        ),
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
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
