// Ye file main.dart ka hissa (part) hai. main.dart me ye line pehle se honi chahiye:
//   part 'chip_content_screen.dart';
part of 'main.dart';

class _ChipData {
  final List<DbRow> chips;
  final List<DbRow> rows;
  const _ChipData(this.chips, this.rows);
}

/// Chapter ke andar ka content: upar square chips (icon upar, naam neeche),
/// chip dabane par sirf usi category ka content.
class ChipContentScreen extends StatefulWidget {
  final DbRow chapter;
  final DbRow subject;
  const ChipContentScreen({
    super.key,
    required this.chapter,
    required this.subject,
  });

  @override
  State<ChipContentScreen> createState() => _ChipContentScreenState();
}

class _ChipContentScreenState extends State<ChipContentScreen> {
  late Future<_ChipData> _future = _load();
  String? _sel;

  Future<_ChipData> _load() async {
    var cats = List<DbRow>.from(await _db
        .from('categories')
        .select()
        .order('sort_order', ascending: true));
    cats = cats.where((c) => c['is_active'] != false).toList();

    // Sirf is class ki categories (admin ne jo tick ki hain), unke order me
    final classId = widget.subject['class_id'];
    if (classId != null) {
      try {
        final cc = await _db
            .from('class_categories')
            .select('category_id, sort_order')
            .eq('class_id', classId);
        final order = <String, num>{
          for (final r in cc)
            '${r['category_id']}': (r['sort_order'] ?? 0) as num
        };
        final mine =
            cats.where((c) => order.containsKey('${c['id']}')).toList();
        mine.sort((a, b) => order['${a['id']}']!.compareTo(order['${b['id']}']!));
        if (mine.isNotEmpty) cats = mine;
      } catch (_) {}
    }

    final data = await _db
        .from('contents')
        .select()
        .eq('chapter_id', widget.chapter['id'])
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    return _ChipData(cats, List<DbRow>.from(data));
  }

  Future<void> _reload() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  // Row kis chip ki hai. Purani rows (category khali) type se jodi jati hain.
  String? _chipOf(DbRow r, List<DbRow> chips) {
    final v = r['category_id'];
    if (v != null && chips.any((c) => '${c['id']}' == '$v')) return '$v';
    if (v == null) {
      final m = chips.where((c) => c['type'] == r['type']);
      if (m.isNotEmpty) return '${m.first['id']}';
    }
    return null;
  }

  IconData _catIcon(dynamic t) {
    final s = '$t';
    if (s == 'video') return Icons.play_circle_outline;
    if (s == 'pdf') return Icons.quiz_outlined;
    return Icons.menu_book_outlined;
  }

  // ------------------------------------------------------------------
  // Square chip: upar icon / photo, neeche naam
  // ------------------------------------------------------------------
  Widget _chip(DbRow c, bool on, int i) {
    final img = imageUrl(c['image_url'] as String?);
    final box = on ? 102.0 : 90.0; // chuna hua chip thoda bada
    final ic = on ? 50.0 : 46.0;
    final fallback = Icon(_catIcon(c['type']),
        size: 28, color: on ? AppDesign.brand : kGrey);
    final icon = Container(
      width: ic,
      height: ic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: img.isEmpty
            ? Center(child: fallback)
            : CachedNetworkImage(
                imageUrl: img,
                fit: BoxFit.cover,
                placeholder: (_, __) => Center(child: fallback),
                errorWidget: (_, __, ___) => Center(child: fallback),
              ),
      ),
    );
    return GestureDetector(
      onTap: () => setState(() => _sel = '${c['id']}'),
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: box,
              height: box,
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              decoration: BoxDecoration(
                color: on ? AppDesign.brand : AppDesign.rowColor(i),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: on ? AppDesign.brand : Colors.black12, width: 1.2),
                boxShadow: on
                    ? [
                        BoxShadow(
                            color: AppDesign.brand.withAlpha(90),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 7),
                  Text(
                    '${c['name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: on ? 13.5 : 12.5,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Chuna hua chip ke neeche nishaan (chhoti patti)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: on ? 34 : 0,
              height: 5,
              decoration: BoxDecoration(
                color: AppDesign.brand,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipBar(List<DbRow> chips, String sel) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesign.bg,
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SizedBox(
        height: 134,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          children: [
            for (var i = 0; i < chips.length; i++)
              _chip(chips[i], '${chips[i]['id']}' == sel, i)
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Content cards
  // ------------------------------------------------------------------
  Widget _pic(String raw, {double ratio = 1}) {
    final img = imageUrl(raw);
    return appCard(
      child: AspectRatio(
        aspectRatio: ratio,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: img.is
