// Ye file main.dart ka hissa (part) hai. main.dart me imports ke neeche ye line rakho:
//   part 'app_design.dart';
// Aur main.dart se purani `class AppDesign` aur `ThemeData _buildTheme()` DELETE kar do.
part of 'main.dart';

/// Admin ke "App Design" se aane wali settings.
/// Internet na ho (ya 4 second me na aaye) to purane rang chalte hain.
class AppDesign {
  static Color brand = kBrand; // header / button / active rang
  static Color brand2 = const Color(0xFFE91E63); // gradient ka doosra rang
  static Color bg = kBg; // screen ka background
  static bool titleLow = false; // "Select Medium" header me ya list ke upar
  static Color? cardSolid; // null = rangeen (har row alag), warna ek hi rang

  /// Medium / Chapter wali rows ka rang
  static Color rowColor(int i) => cardSolid ?? _kRowBg[i % _kRowBg.length];

  /// Safed card ki jagah use hone wala rang (Subject card, video card...)
  static Color get cardBase => cardSolid ?? Colors.white;

  static Color _hex(dynamic v, Color d) {
    var s = '${v ?? ''}'.replaceAll('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    final n = int.tryParse(s, radix: 16);
    return n == null ? d : Color(n);
  }

  static Future<void> load() async {
    try {
      final r = await Supabase.instance.client
          .from('app_design')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));
      if (r == null) return;
      brand = _hex(r['brand_color'], kBrand);
      brand2 = _hex(r['brand_color2'], const Color(0xFFE91E63));
      bg = _hex(r['bg_color'], kBg);
      titleLow = r['title_low'] == true;
      final c = '${r['card_color'] ?? ''}'.trim();
      cardSolid = (c.isEmpty || c == 'multi') ? null : _hex(c, Colors.white);
    } catch (_) {}
  }
}

/// Poore app ka theme: AppBar, background aur spinner admin ke rang se
ThemeData _buildTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppDesign.brand),
    scaffoldBackgroundColor: AppDesign.bg,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: AppDesign.brand,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: AppDesign.brand),
  );
  return base.copyWith(textTheme: GoogleFonts.poppinsTextTheme(base.textTheme));
}
