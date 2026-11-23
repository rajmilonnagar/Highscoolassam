// Ye file main.dart ka hissa hai (part), isliye iska apna import nahi hai.
// main.dart me imports ke neeche ye line honi chahiye:  part 'chip_content_screen.dart';
part of 'main.dart';

/// Chapter ka content: upar sliding chips (photo + naam), tap karo to sirf usi category ka material.
/// Purana ContentScreen jaisa hai bas 3 fixed tab ki jagah chips admin se aate hain.
class ChipContentScreen extends StatefulWidget {
  final DbRow chapter;
  final DbRow subject; // subject['class_id'] se pata chalta hai kaun si categories dikhani hain
  const ChipContentScreen({super.key, required this.chapter, required this.subject});

  @override
  State<ChipContentScreen> createState() => _ChipContentScreenState();
}

class _ChipContentScreenState extends State<ChipContentScreen> {
  bool _loading = true;
  bool _failed = false;
  List<DbRow> _cats = [];
  Map<dynamic, List<DbRow>> _content = {};
  List<GlobalKey> _keys = [];
  int _sel = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // 1) Is class ke liye kaun si categories, kis order me
      final mapped = await _db
          .from('class_categories')
          .select('sort_order, categories(*)')
          .eq('class_id', widget.subject['class_id'])
          .order('sort_order', ascending: true);

      List<DbRow> list = [];
      for (final m in mapped) {
        final c = m['categories'];
        if (c != null && c['is_active'] != false) {
          list.add(Map<String, dynamic>.from(c));
        }
      }
      // Class ki mapping khali ho to sab active categories
      if (list.isEmpty) {
        final all = await _db
            .from('categories')
            .select()
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        list = List<DbRow>.from(all);
      }

      // 2) Is chapter ka poora content ek baar me
      final rows = await _db
          .from('contents')
          .select()
          .eq('chapter_id', widget.chapter['id'])
          .order('sort_order', ascending: true);

      // 3) Category ke hisab se baantna.
      //    Purani rows (category_id khali) ko unke type (video/pdf/qa) se jodte hain,
      //    taaki purana admin app bhi chalta rahe.
      final map = <dynamic, List<DbRow>>{};
      for (final r in rows) {
        dynamic key = r['category_id'];
        if (key == null) {
          final m = list.where((c) => c['type'] == r['type']);
          if (m.isEmpty) continue;
          key = m.first['id'];
        }
        (map[key] ??= []).add(Map<String, dynamic>.from(r));
      }

      // 4) Jis category me content nahi, uska chip hide
      list = list.where((c) => (map[c['id']] ?? []).isNotEmpty).toList();

      if (!mounted) return;
      setState(() {
        _cats = list;
        _content = map;
        _keys = List.generate(list.length, (_) => GlobalKey());
        _sel = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _select(int i) {
    setState(() => _sel = i);
    final ctx = _keys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.5, duration: const Duration(milliseconds: 250));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text('${widget.chapter['name']}'),
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kBrand));
    }
    if (_failed) {
      return _Message(text: 'Data load nahi hua.', onRetry: _load);
    }
    if (_cats.isEmpty) {
      return _Message(text: 'Is chapter me material jald aayega.', onRetry: _load);
    }
    return Column(
      children: [
        _chips(),
        const Divider(height: 1),
        Expanded(child: _items()),
      ],
    );
  }

  // ---------------- S
