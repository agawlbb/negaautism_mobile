import 'package:flutter/material.dart';

// Colors from the website's public interface.css and branding strip.
const websiteInk = Color(0xff203d42);
const websiteTeal = Color(0xff17685f);
const websiteBackground = Color(0xfff6f8f4);
const websiteBrandGradient = LinearGradient(
  colors: [
    Color(0xff3399ff),
    Color(0xff71e17c),
    Color(0xffffcc00),
    Color(0xffff6666),
  ],
);

class WebsiteHeaderTitle extends StatelessWidget {
  final String title;
  const WebsiteHeaderTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Image.asset(
        'assets/images/nega_logo.png',
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

ThemeData websiteTheme() {
  final colors = ColorScheme.fromSeed(seedColor: websiteTeal).copyWith(
    primary: websiteTeal,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: websiteInk,
    outline: const Color(0xff8b9d99),
    outlineVariant: const Color(0xffd7e3df),
  );
  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: websiteBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: websiteInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff8b9d99)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      textColor: websiteInk,
      collapsedTextColor: websiteInk,
      iconColor: websiteTeal,
      collapsedIconColor: websiteTeal,
      shape: Border(),
      collapsedShape: Border(),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: websiteTeal,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xffd7e3df)),
      ),
    ),
  );
}
