// Ye file main.dart ka hissa (part) hai. main.dart me ye line pehle se honi chahiye:
//   part 'chip_content_screen.dart';
part of 'main.dart';

const Color _kLine = Color(0xFFE5E7EB);

/// Chapter ke andar ka content:
///  - Upar chhota AppBar (44) + bade square chips. Neeche scroll karte hi dono
///    chhup jate hain, upar scroll karte hi wapas aa jate hain.
///  - Chip dabane par sirf usi tab ka data Supabase se aata hai.
///  - Cards poori chaudai ke, bahar koi gap nahi, beech me 1px ki line.
///  - Poore page ka sirf ek scroll (andar koi alag scroll nahi).
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
  final ScrollController _scroll = ScrollController();

  // Chips
  List<DbRow> _chips = [];
  bool _chipsLoading = true;
  bool _chipsError = false;
  String? _sel;

  // Chune hue tab ka content
  List<DbRow> _rows = [];
  bool _rowsLoading = false;
  bool _rowsError = false;
  int _req = 0; // purani request ka jawab ignore karne ke liye

  @override
  void initState() {
    super.initState();
    _loadChips();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DbRow? get _selChip {
    for (final c in _chips) {
      if ('${c['id']}' == _sel) return c;
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Supabase: chips
  // ------------------------------------------------------------------
  Future<List<DbRow>> _fetchChips() async {
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
        mine.sort(
            (a, b) => order['${a['id']}']!.compareTo(order['${b['id']}']!));
        if (mine.isNotEmpty) cats = mine;
      } catch (_) {}
    }
    return cats;
  }

  Future<void> _loadChips({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _chipsLoading = true;
        _chipsError = false;
      });
    }
    try {
      final chips = await _fetchChips();
      if (!mounted) return;
      final ids = chips.map((c) => '${c['id']}').toList();
      setState(() {
        _chips = chips;
        _sel = (_sel != null && ids.contains(_sel))
            ? _sel
            : (ids.isNotEmpty ? ids.first : null);
        _chipsLoading = false;
        _chipsError = false;
      });
      await _loadRows(silent: silent);
    } catch (e) {
      debugPrint('Chips load error: $e');
      if (!mounted) return;
      if (silent && _chips.isNotEmpty) {
        _snack('Refresh nahi ho paya. Internet check karein.');
      } else {
        setState(() {
          _chipsLoading = false;
          _chipsError = true;
        });
      }
    }
  }

  // ------------------------------------------------------------------
  // Supabase: chune hue chip ka content
  // ------------------------------------------------------------------
  Future<List<DbRow>> _fetchRows() async {
    var q = _db.from('contents').select().eq('chapter_id', widget.chapter['id']);

    final chip = _selChip;
    if (chip != null) {
      final id = chip['id'];
      final type = chip['type'];
      // Purani rows (category khali) type se pehle usi type wale chip ko milti hain
      var ownsLegacy = false;
      if (type != null && '$type'.isNotEmpty) {
        for (final c in _chips) {
          if (c['type'] == type) {
            ownsLegacy = '${c['id']}' == '$id';
            break;
          }
        }
      }
      if (ownsLegacy) {
        q = q.or('category_id.eq.$id,and(category_id.is.null,type.eq.$type)');
      } else {
        q = q.eq('category_id', id);
      }
    }

    final data = await q
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    return List<DbRow>.from(data);
  }

  Future<void> _loadRows({bool silent = false}) async {
    final my = ++_req;
    if (!silent) {
      setState(() {
        _rowsLoading = true;
        _rowsError = false;
      });
    }
    try {
      final data = await _fetchRows();
      if (!mounted || my != _req) return;
      setState(() {
        _rows = data;
        _rowsLoading = false;
        _rowsError = false;
      });
    } catch (e) {
      debugPrint('Rows load error: $e');
      if (!mounted || my != _req) return;
      if (silent && _rows.isNotEmpty) {
        _snack('Refresh nahi ho paya. Internet check karein.');
      } else {
        setState(() {
          _rowsLoading = false;
          _rowsError = true;
        });
      }
    }
  }

  Future<void> _refresh() => _loadChips(silent: true);

  void _snack(String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  void _select(String id) {
    if (id == _sel) return;
    setState(() {
      _sel = id;
      _rows = [];
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _loadRows();
  }

  IconData _catIcon(dynamic t) {
    final s = '$t';
    if (s == 'video') return Icons.play_circle_outline;
    if (s == 'pdf') return Icons.quiz_outlined;
    return Icons.menu_book_outlined;
  }

  // ------------------------------------------------------------------
  // Square chip: upar icon / photo, neeche naam (pehle jaise bade)
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
      onTap: () => _select('${c['id']}'),
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

  static const double _chipBarH = 135; // 134 + neeche ki 1px line

  Widget _chipBar() {
    return SizedBox(
      height: _chipBarH,
      child: Container(
        decoration: BoxDecoration(
          color: AppDesign.bg,
          border: const Border(bottom: BorderSide(color: _kLine)),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          children: [
            for (var i = 0; i < _chips.length; i++)
              _chip(_chips[i], '${_chips[i]['id']}' == _sel, i)
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Content: text, image (caption ke saath), link (web) - sab poori chaudai
  // ------------------------------------------------------------------
  static final RegExp _linkRe = RegExp(r'https?://[^\s]+');

  bool _isPdfLink(String u) {
    final l = u.toLowerCase().split('?').first;
    return l.endsWith('.pdf') || _driveId(u) != null;
  }

  // Google Drive photo ho to badi (w1200) photo, warna waisi hi
  String _bigImg(String raw) {
    final id = _driveId(raw.trim());
    if (id != null) return 'https://lh3.googleusercontent.com/d/$id=w1200';
    return imageUrl(raw);
  }

  Widget _fullImage(String raw) {
    final img = _bigImg(raw);
    if (img.isEmpty) return const SizedBox.shrink();
    return CachedNetworkImage(
      imageUrl: img,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      placeholder: (_, __) => SizedBox(
        height: 200,
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppDesign.brand)),
      ),
      errorWidget: (_, __, ___) => const SizedBox(
        height: 120,
        child: Center(
            child: Icon(Icons.broken_image_outlined, size: 48, color: kGrey)),
      ),
    );
  }

  Widget _textBlock
