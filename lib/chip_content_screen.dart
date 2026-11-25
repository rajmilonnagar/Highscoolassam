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
    final fallback = Icon(_catIcon(c['type']),
        size: 28, color: on ? AppDesign.brand : kGrey);
    final icon = Container(
      width: 46,
      height: 46,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 94,
        height: 94,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
        decoration: BoxDecoration(
          color: on ? AppDesign.brand : AppDesign.rowColor(i),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on ? AppDesign.brand : Colors.black12,
              width: 1.2),
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
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : const Color(0xFF1F2937),
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
        height: 114,
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
          child: img.isEmpty
              ? const Center(
                  child: Icon(Icons.image_outlined, size: 48, color: kThumbBg))
              : CachedNetworkImage(
                  imageUrl: img,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppDesign.brand)),
                  errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 48, color: kGrey)),
                ),
        ),
      ),
    );
  }

  Widget _videoCard(DbRow r) {
    final title = '${r['title'] ?? ''}'.trim();
    final url = '${r['url'] ?? ''}'.trim();
    var img = imageUrl(r['image_url'] as String?);
    if (img.isEmpty) {
      final yt = youtubeId(url);
      if (yt != null) img = 'https://img.youtube.com/vi/$yt/hqdefault.jpg';
    }
    final fallback = Container(
      color: kThumbBg,
      child: Center(
          child: Icon(Icons.play_circle_fill, color: AppDesign.brand, size: 56)),
    );
    return appCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: url.isEmpty
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: url)),
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  img.isEmpty
                      ? fallback
                      : CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: kThumbBg),
                          errorWidget: (_, __, ___) => fallback,
                        ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                          color: Colors.black45, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow,
                          color: Colors.white, size: 34),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoCard(DbRow r) {
    final title = '${r['title'] ?? ''}'.trim();
    final body = '${r['body'] ?? ''}'.trim();
    final p1 = '${r['image_url'] ?? ''}'.trim();
    final p2 = '${r['image_url2'] ?? ''}'.trim();
    final Widget pics = (p1.isNotEmpty && p2.isNotEmpty)
        ? Row(
            children: [
              Expanded(child: _pic(p1)),
              const SizedBox(width: 14),
              Expanded(child: _pic(p2)),
            ],
          )
        : _pic(p1.isNotEmpty ? p1 : p2, ratio: 16 / 10);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          pics,
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937)),
              ),
            ),
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: kGrey)),
            ),
        ],
      ),
    );
  }

  Widget _item(DbRow r) {
    final type = '${r['type'] ?? ''}';
    final p1 = '${r['image_url'] ?? ''}'.trim();
    final p2 = '${r['image_url2'] ?? ''}'.trim();
    if (type == 'video') return _videoCard(r);
    if (type != 'pdf' && (p1.isNotEmpty || p2.isNotEmpty)) {
      return _photoCard(r);
    }
    // PDF / txt / sirf text: text + link seedha card me load
    return _AutoCard(
      title: '${r['title'] ?? ''}'.trim(),
      body: '${r['body'] ?? ''}'.trim(),
      url: '${r['url'] ?? ''}'.trim(),
    );
  }

  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.bg,
      appBar: AppBar(
        title: Text('${widget.chapter['name'] ?? ''}'),
        backgroundColor: AppDesign.brand,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<_ChipData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(
                child: CircularProgressIndicator(color: AppDesign.brand));
          }
          if (snap.hasError || snap.data == null) {
            return _Message(
              text: 'Data load nahi hua. Internet check karein.',
              onRetry: _reload,
            );
          }
          final d = snap.data!;
          final ids = d.chips.map((c) => '${c['id']}').toList();
          final sel = (_sel != null && ids.contains(_sel))
              ? _sel!
              : (ids.isNotEmpty ? ids.first : '_none');
          final rows = d.chips.isEmpty
              ? d.rows
              : d.rows.where((r) => _chipOf(r, d.chips) == sel).toList();

          return Column(
            children: [
              if (d.chips.isNotEmpty) _chipBar(d.chips, sel),
              Expanded(
                child: RefreshIndicator(
                  color: AppDesign.brand,
                  onRefresh: _reload,
                  child: rows.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(
                              child: Text('Jald aayega',
                                  style:
                                      TextStyle(color: kGrey, fontSize: 18)),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                          itemCount: rows.length,
                          itemBuilder: (context, i) => _item(rows[i]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
