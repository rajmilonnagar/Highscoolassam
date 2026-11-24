// Ye file main.dart ka hissa (part) hai, isliye iska apna import nahi hai.
// main.dart me imports ke neeche ye line honi chahiye:  part 'notice_banner.dart';
part of 'main.dart';

/// Pehli screen ke upar:
///  1) Samay ke hisab se greeting (Good Morning / Afternoon / Evening / Night)
///     aur roz badalne wali ek chhoti prerna wali line
///  2) Admin ka likha notice / shubhkamna banner (Supabase `notices` table se)
class NoticeBanner extends StatefulWidget {
  /// Medium chunne ke baad wali screen par medium ki row do (greeting uski bhasha me aayegi).
  /// Pehli screen par null rakhein: tab sirf English greeting aur "sab medium" wale notice dikhte hain.
  final DbRow? medium;
  const NoticeBanner({super.key, this.medium});

  @override
  State<NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<NoticeBanner> {
  List<DbRow> _items = [];
  bool _hidden = false;
  int _page = 0;
  final PageController _pc = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('notices')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      final now = DateTime.now();
      final list = <DbRow>[];
      for (final r in rows) {
        final s = DateTime.tryParse('${r['start_date'] ?? ''}');
        final e = DateTime.tryParse('${r['end_date'] ?? ''}');
        if (s != null && now.isBefore(s)) continue; // abhi shuru nahi hua
        if (e != null && now.isAfter(e.add(const Duration(days: 1)))) continue; // expire
        // medium_id khali = sab ke liye, nahi to sirf usi medium ke liye
        final mid = r['medium_id'];
        if (mid != null && mid != widget.medium?['id']) continue;
        list.add(Map<String, dynamic>.from(r));
      }
      if (!mounted) return;
      setState(() => _items = list);
    } catch (_) {
      // Banner na aaye to koi baat nahi, greeting aur app chalte rahenge
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = !_hidden && _items.isNotEmpty;
    return Column(
      children: [
        _greeting(),
        if (showBanner) _banner(),
      ],
    );
  }

  // ---------------- Samay ke hisab se greeting ----------------
  // Local bhasha ke shabd database ki `mediums` table se aate hain
  // (greet_morning / greet_afternoon / greet_evening / greet_night). Khali ho to sirf English.
  Widget _greeting() {
    final now = DateTime.now();
    final h = now.hour;

    late String en;
    late String key;
    late IconData icon;
    late Color col;
    late List<String> lines;

    if (h >= 5 && h < 12) {
      en = 'Good Morning';
      key = 'greet_morning';
      icon = Icons.wb_sunny_rounded;
      col = const Color(0xFFF59E0B);
      lines = [
        'Aaj ka pehla chapter padhkar din shuru karein',
        'Chhota sa revision, bada fayda',
        'Aaj kam se kam ek video zaroor dekhein',
      ];
    } else if (h >= 12 && h < 17) {
      en = 'Good Afternoon';
      key = 'greet_afternoon';
      icon = Icons.light_mode_rounded;
      col = const Color(0xFFEA580C);
      lines = [
        'Thoda break lekar ek MCQ test try karein',
        'Aaj kitna padha? Ek chapter aur dekhein',
        'Pichhle chapter ke sawal ek baar dohra lein',
      ];
    } else if (h >= 17 && h < 21) {
      en = 'Good Evening';
      key = 'greet_evening';
      icon = Icons.wb_twilight_rounded;
      col = const Color(0xFF7C3AED);
      lines = [
        'Aaj jo padha, use ek baar revise kar lein',
        'Kal ke test ki taiyari abhi se shuru karein',
        'Important questions aaj hi dekh lein',
      ];
    } else {
      en = 'Good Night';
      key = 'greet_night';
      icon = Icons.nights_stay_rounded;
      col = const Color(0xFF4F46E5);
      lines = [
        'Aaj ke liye ek topic aur, phir aaram karein',
        'Neend poori lein, kal phir padhenge',
        'Aaj ki mehnat ke liye shabash!',
      ];
    }

    final native = '${widget.medium?[key] ?? ''}'.trim();
    final title = native.isEmpty ? en : '$en  ·  $native';

    // Roz alag line (din ke number se), kuch save karne ki zarurat nahi
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final line = lines[dayOfYear % lines.length];

    return appCard(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: col.withAlpha(40),
              child: Icon(icon, color: col, size: 26),
            ),
            const SizedBox
