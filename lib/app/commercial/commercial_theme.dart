import 'package:flutter/material.dart';

import '../shared/ui_contract_core/theme/contract_tokens.dart';

const ContractAreaTokens commercialAreaTokens = ContractAreaTokens(
  primary: Color(0xFFE2B14F),
  primaryStrong: Color(0xFFF5D78A),
  primarySoft: Color(0xFF2A2B1C),
  accent: Color(0xFF8BC6A2),
  surfaceTint: Color(0xFF556B5D),
  border: Color(0xFF7C8F82),
  badgeBackground: Color(0xFF1A221E),
  badgeText: Color(0xFFEAF3EC),
  glow: Color(0xFF8BC6A2),
  darkGlass: true,
  glassSurface: Color(0x52303A34),
  fieldSurface: Color(0x7A111915),
  onGlass: Color(0xFFF1F5F2),
);

const LinearGradient kCommercialHeroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B0F0D), Color(0xFF151C18), Color(0xFF213128)],
);

const LinearGradient kCommercialPanelGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF141B17), Color(0xFF212B25)],
);

const LinearGradient kCommercialAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF5D78A), Color(0xFF8BC6A2), Color(0xFF1A221E)],
);

const Color kCommercialInk = Color(0xFFF1F5F2);
const Color kCommercialMutedInk = Color(0xFFBBC8C0);

ThemeData buildCommercialAreaTheme(ThemeData base) {
  const surface = Color(0xFF141B17);
  const surfaceSoft = Color(0xFF1B221F);
  const outline = Color(0xFF7C8F82);
  const accent = Color(0xFF8BC6A2);
  const ink = kCommercialInk;
  const mutedInk = kCommercialMutedInk;

  final colorScheme = const ColorScheme.dark(
    primary: Color(0xFFE2B14F),
    secondary: accent,
    surface: surface,
    onSurface: ink,
    error: Color(0xFFCC4B37),
    onPrimary: ink,
    onSecondary: ink,
  );

  InputDecorationTheme inputDecorationTheme() => InputDecorationTheme(
    filled: true,
    fillColor: const Color(0x66101713),
    labelStyle: const TextStyle(color: Color(0xD9F3F1E8)),
    floatingLabelStyle: const TextStyle(color: ink),
    hintStyle: const TextStyle(color: Color(0x99F3F1E8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: accent),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: outline),
    ),
  );

  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: surfaceSoft,
    cardColor: surface,
    dividerColor: Colors.white.withValues(alpha: 0.08),
    inputDecorationTheme: inputDecorationTheme(),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ink,
      selectionColor: Color(0x6641D978),
      selectionHandleColor: accent,
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      textStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(backgroundColor: WidgetStatePropertyAll(surfaceSoft)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceSoft,
      textStyle: const TextStyle(color: ink, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceSoft,
      titleTextStyle: const TextStyle(
        color: ink,
        fontWeight: FontWeight.w900,
        fontSize: 24,
      ),
      contentTextStyle: const TextStyle(color: mutedInk, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surfaceSoft,
      headerForegroundColor: ink,
      dayForegroundColor: const WidgetStatePropertyAll(ink),
      yearForegroundColor: const WidgetStatePropertyAll(ink),
      weekdayStyle: const TextStyle(color: mutedInk),
      dayBackgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      todayForegroundColor: const WidgetStatePropertyAll(accent),
      todayBorder: const BorderSide(color: accent),
      yearBackgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: ink,
        backgroundColor: const Color(0xFF183826),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: const WidgetStatePropertyAll(accent),
      checkColor: const WidgetStatePropertyAll(Color(0xFF0E1612)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(accent),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0x6641D978)
            : Colors.white.withValues(alpha: 0.18),
      ),
    ),
  );
}
