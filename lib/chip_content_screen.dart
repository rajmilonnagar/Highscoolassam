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

  Widget _textBlock(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SelectableText(t,
            style: const TextStyle(
                fontSize: 16, height: 1.5, color: Color(0xFF1F2937))),
      );

  Widget _linkWidget(String link, String title) {
    if (_AutoCard._isTxt(link)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ColoredTxtView(url: link),
      );
    }
    if (_AutoCard._isImg(link)) return _fullImage(link);
    if (_isPdfLink(link)) {
      return _AutoWebView(
        title: title,
        url: pdfUrl(link),
        minHeight: MediaQuery.of(context).size.height * 0.68,
      );
    }
    return _AutoWebView(title: title, url: link);
  }

  // Text + link (PDF / txt / web / sirf text)
  Widget _textLinkItem(DbRow r) {
    final title = '${r['title'] ?? ''}'.trim();
    final body = '${r['body'] ?? ''}'.trim();
    final url = '${r['url'] ?? ''}'.trim();

    final parts = <Widget>[];
    final seen = <String>{};
    var last = 0;
    for (final m in _linkRe.allMatches(body)) {
      final link = m.group(0)!.replaceAll(RegExp(r'[).,;]+$'), '');
      final before = body.substring(last, m.start).trim();
      if (before.isNotEmpty) parts.add(_textBlock(before));
      seen.add(link);
      parts.add(_linkWidget(link, title));
      last = m.start + link.length;
    }
    final tail = body.substring(last).trim();
    if (tail.isNotEmpty) parts.add(_textBlock(tail));
    if (_linkRe.hasMatch(url) && !seen.contains(url)) {
      parts.add(_linkWidget(url, title));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937))),
          ),
        ...parts,
        const SizedBox(height: 4),
      ],
    );
  }

  // Photo (1 ya 2) + caption (title / body)
  Widget _imageItem(DbRow r) {
    final title = '${r['title'] ?? ''}'.trim();
    final body = '${r['body'] ?? ''}'.trim();
    final p1 = '${r['image_url'] ?? ''}'.trim();
    final p2 = '${r['image_url2'] ?? ''}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p1.isNotEmpty) _fullImage(p1),
        if (p2.isNotEmpty) _fullImage(p2),
        if (title.isNotEmpty || body.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                if (title.isNotEmpty)
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937))),
                if (body.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: title.isNotEmpty ? 4 : 0),
                    child: Text(body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: kGrey)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _videoItem(DbRow r) {
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
    return InkWell(
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
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
    );
  }

  Widget _item(DbRow r) {
    final type = '${r['type'] ?? ''}';
    final p1 = '${r['image_url'] ?? ''}'.trim();
    final p2 = '${r['image_url2'] ?? ''}'.trim();
    if (type == 'video') return _videoItem(r);
    if (type != 'pdf' && (p1.isNotEmpty || p2.isNotEmpty)) {
      return _imageItem(r);
    }
    return _textLinkItem(r);
  }

  // Card: poori chaudai, bahar koi gap nahi, do cards ke beech sirf 1px line
  Widget _cardShell(int i, DbRow r) {
    return _KeepAlive(
      key: ValueKey('${r['id']}_$i'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppDesign.cardBase,
          border: i == 0
              ? null
              : const Border(top: BorderSide(color: _kLine, width: 1)),
        ),
        child: _item(r),
      ),
    );
  }

  // ------------------------------------------------------------------
  Widget _center(Widget w) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: w),
      );

  List<Widget> _contentSlivers() {
    if (_chipsLoading || _rowsLoading) {
      return [
        _center(CircularProgressIndicator(color: AppDesign.brand)),
      ];
    }
    if (_chipsError) {
      return [
        _center(_Message(
          text: 'Data load nahi hua. Internet check karein.',
          onRetry: _loadChips,
        )),
      ];
    }
    if (_rowsError) {
      return [
        _center(_Message(
          text: 'Data load nahi hua. Internet check karein.',
          onRetry: _loadRows,
        )),
      ];
    }
    if (_rows.isEmpty) {
      return [
        _center(const Text('Jald aayega',
            style: TextStyle(color: kGrey, fontSize: 18))),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _cardShell(i, _rows[i]),
          childCount: _rows.length,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppDesign.bg,
        // Neeche ki navigation bar ke liye SafeArea
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Status bar ki jagah hamesha brand rang
              Container(height: topPad, color: AppDesign.brand),
              Expanded(
                child: RefreshIndicator(
                  color: AppDesign.brand,
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        floating: true,
                        snap: true,
                        pinned: false,
                        primary: false,
                        toolbarHeight: 44,
                        elevation: 0,
                        scrolledUnderElevation: 0,
                        surfaceTintColor: Colors.transparent,
                        backgroundColor: AppDesign.brand,
                        foregroundColor: Colors.white,
                        titleSpacing: 0,
                        title: Text(
                          '${widget.chapter['name'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        bottom: _chips.isNotEmpty
                            ? PreferredSize(
                                preferredSize: const Size.fromHeight(_chipBarH),
                                child: _chipBar(),
                              )
                            : null,
                      ),
                      ..._contentSlivers(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab ke andar ke items scroll hone par bhi bane rahein (webview dobara load
// na ho aur unki unchai na badle)
// ---------------------------------------------------------------------------
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({super.key, required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ---------------------------------------------------------------------------
// Web link: page ki poori unchai tak failta hai, andar alag scroll nahi.
// Upar/neeche ka drag seedha poore page ko scroll karta hai.
// ---------------------------------------------------------------------------
class _AutoWebView extends StatefulWidget {
  final String title;
  final String url;
  final double minHeight;
  const _AutoWebView({
    required this.title,
    required this.url,
    this.minHeight = 300,
  });

  @override
  State<_AutoWebView> createState() => _AutoWebViewState();
}

class _AutoWebViewState extends State<_AutoWebView> {
  static const double _maxH = 30000;

  late final WebViewController _c;
  late double _h = widget.minHeight;
  bool _loading = true;

  // Page ki unchai kuch baar naapkar Flutter ko bhejta hai (bar bar nahi,
  // taaki 100vh wale pages ki unchai badhti na jaye).
  static const String _js = '''
(function(){
  var e=document.documentElement,b=document.body;
  e.style.overflow='hidden'; if(b){b.style.overflow='hidden';}
  function send(){
    var h=Math.max(e.scrollHeight,b?b.scrollHeight:0);
    SizeChannel.postMessage(String(h));
  }
  send();
  [300,1000,2500,5000].forEach(function(t){setTimeout(send,t);});
})();
''';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'SizeChannel',
        onMessageReceived: (m) {
          final v = double.tryParse(m.message);
          if (v == null || !mounted) return;
          final nh = v.clamp(widget.minHeight, _maxH).toDouble();
          if ((nh - _h).abs() > 2) setState(() => _h = nh);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          _c.runJavaScript(_js);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  void _full() => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => WebViewScreen(
                title: widget.title.isEmpty ? 'File' : widget.title,
                url: widget.url)),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _h,
      child: Stack(
        children: [
          // gestureRecognizers khali: vertical drag poore page ko jata hai
          Positioned.fill(child: WebViewWidget(controller: _c)),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: Center(
                    child: CircularProgressIndicator(color: AppDesign.brand)),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.white70,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Poori screen',
                icon: Icon(Icons.open_in_full, color: AppDesign.brand, size: 20),
                onPressed: _full,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
