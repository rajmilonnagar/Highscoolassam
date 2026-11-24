import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_category_screens.dart';
import 'admin_notice_screen.dart';

const supabaseUrl = 'https://ymiakzzapyhybtoumtbx.supabase.co';
const supabaseKey = 'sb_publishable_9AC4HbjXewYpiJGOGMPz_A_HKdVimOl';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const AdminApp());
}

final db = Supabase.instance.client;
typedef DbRow = Map<String, dynamic>;

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assam Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snap) {
        if (db.auth.currentSession == null) return const LoginScreen();
        return mediumsScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await db.auth.signInWithPassword(
          email: _email.text.trim(), password: _pass.text);
    } catch (e) {
      setState(() => _error = 'Login nahi hua. Email/password check karein.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, size: 72, color: Colors.indigo),
              const SizedBox(height: 8),
              const Text('Assam Admin',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder()),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _login,
                  child: Text(_busy ? 'Ruko...' : 'Login'),
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
// Screens: Medium -> Class -> Subject -> Chapter -> Content
// ---------------------------------------------------------------------------

const _nameImgOrder = [
  F('name', 'Naam'),
  F('image_url', 'Photo link (Google Drive)'),
  F('sort_order', 'Order (1,2,3...)', number: true),
];

Widget mediumsScreen() => TableScreen(
      title: 'Mediums',
      table: 'mediums',
      fields: [
        ..._nameImgOrder,
        const F('greet_morning', 'Subah ka shabd (Good Morning ki jagah, us bhasha me)'),
        const F('greet_afternoon', 'Dopahar ka shabd (Good Afternoon)'),
        const F('greet_evening', 'Shaam ka shabd (Good Evening)'),
        const F('greet_night', 'Raat ka shabd (Good Night)'),
      ],
      titleKey: 'name',
      isRoot: true,
      child: (m) => classesScreen(m),
    );

Widget classesScreen(DbRow m) => TableScreen(
      title: '${m['name']} - Classes',
      table: 'classes',
      fields: _nameImgOrder,
      titleKey: 'name',
      child: (c) => subjectsScreen(m, c),
    );

Widget subjectsScreen(DbRow m, DbRow c) => TableScreen(
      title: '${c['name']} - Subjects',
      table: 'subjects',
      filter: {'medium_id': m['id'], 'class_id': c['id']},
      fields: _nameImgOrder,
      titleKey: 'name',
      bulk: true,
      child: (s) => chaptersScreen(s),
    );

Widget chaptersScreen(DbRow s, [DbRow? parent]) => TableScreen(
      title: parent == null
          ? '${s['name']} - Chapters'
          : '${parent['name']} - Sub-chapters',
      table: 'chapters',
      filter: {
        'subject_id': s['id'],
        if (parent != null) 'parent_id': parent['id'],
      },
      nullFilter: parent == null ? const ['parent_id'] : const [],
      fields: const [
        F('name', 'Chapter ka naam'),
        F('subtitle', 'Chhota text (optional)'),
        F('image_url', 'Photo link (Google Drive)'),
        F('sort_order', 'Order (1,2,3...)', number: true),
      ],
      titleKey: 'name',
      subtitleKey: 'subtitle',
      child: (ch) => contentsScreen(ch, s['class_id']),
      bulk: true,
      extraIcon: Icons.account_tree,
      extraTooltip: 'Sub-chapters (chhote chapter)',
      extra: (ch) => chaptersScreen(s, ch),
    );

Widget contentsScreen(DbRow ch, [dynamic classId]) => TableScreen(
      title: '${ch['name']} - Content',
      table: 'contents',
      filter: {'chapter_id': ch['id']},
      fields: const [
        F('category_id', 'Category', fromTable: 'categories'),
        F('title', 'Title'),
        F('url', 'Video ka link', types: {'single_video'}),
        F('url', '.txt file ka link', types: {'text_file'}),
        F('image_url', 'Video thumbnail ka link', types: {'single_video'}),
        F('image_url', 'Photo ka link', types: {'single_photo'}),
        F('image_url', 'Photo 1 ka link (baayein card)', types: {'double'}),
        F('image_url2', 'Photo 2 ka link (daayein card)', types: {'double'}),
        F('body', 'Neeche ka text (optional, dabakar likhein)',
            multiline: true,
            types: {'single_photo', 'single_video', 'double'}),
        F('body', 'Text (dabakar poora likhein)',
            multiline: true, types: {'text_keyboard'}),
      ],
      modeSelect: true, // Add par Single / Double / Plain text chunna
      reorder: true, // order list me pakad kar upar-neeche karke badlein
      titleKey: 'title',
      subtitleKey: 'type',
      chipsTable: 'categories', // upar category chips, dabane par sirf usi ka content
      chipsClassId: classId, // sirf is class ki categories ke chips (class_categories se)
      chipsFallbackKey: 'type', // purani rows (category khali) type se jud jati hain
    );

// ---------------------------------------------------------------------------
// Generic table screen: list + add + edit + delete
// ---------------------------------------------------------------------------

class F {
  final String key;
  final String label;
  final bool multiline;
  final bool number;
  final List<String>? options;
  // Dropdown jo database ki table se aata hai (jaise categories)
  final String? fromTable;
  final String labelKey; // dropdown me kaun sa column dikhe
  final Map<String, String> copy; // chuni row ka column -> is row ke column me copy
  final Set<String>? types; // diya ho to ye field sirf in category-types me dikhe
  const F(this.key, this.label,
      {this.multiline = false,
      this.number = false,
      this.options,
      this.fromTable,
      this.labelKey = 'name',
      this.copy = const {},
      this.types});
}

class _KindChooser extends StatelessWidget {
  const _KindChooser();

  Widget _card(BuildContext c, String kind, IconData icon, String title,
      String sub) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 40, color: Colors.indigo),
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pop(c, kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kaisa card banana hai?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(context, 'single', Icons.crop_square, 'Single card',
              'Ek bada card: photo ka link ya video ka link'),
          _card(context, 'double', Icons.view_column_outlined, 'Double card',
              'Do card ek saath: photo 1 aur photo 2 ka link'),
          _card(context, 'text', Icons.notes, 'Plain text',
              '.txt file ka link ya keyboard se likhna'),
        ],
      ),
    );
  }
}

class TableScreen extends StatefulWidget {
  final String title;
  final String table;
  final Map<String, dynamic> filter;
  final List<F> fields;
  final String titleKey;
  final String? subtitleKey;
  final Widget Function(DbRow row)? child;
  final bool isRoot;
  final List<String> nullFilter; // in columns ka value khali (null) wale hi dikhao
  final Widget Function(DbRow row)? extra; // doosra button (jaise sub-chapters)
  final IconData extraIcon;
  final String extraTooltip;
  final bool bulk; // ek saath kai naam add karne ka button
  // Upar chips: is table (jaise 'categories') ki rows chips banengi, aur list us chip ki rows tak simit rahegi
  final String? chipsTable;
  final String chipsKey; // is screen ki row ka column jo chip se jodta hai
  final String chipsLabelKey; // chip par kya likha dikhe
  final String? chipsFallbackKey; // chipsKey khali ho to is column se milao (jaise type)
  final dynamic chipsClassId; // diya ho to chips sirf is class ki categories ke
  final bool reorder; // list me drag karke order badalna
  final bool modeSelect; // Add par Single / Double / Plain text card chunna

  const TableScreen({
    super.key,
    required this.title,
    required this.table,
    required this.fields,
    required this.titleKey,
    this.filter = const {},
    this.subtitleKey,
    this.child,
    this.isRoot = false,
    this.nullFilter = const [],
    this.extra,
    this.extraIcon = Icons.more_horiz,
    this.extraTooltip = '',
    this.bulk = false,
    this.chipsTable,
    this.chipsKey = 'category_id',
    this.chipsLabelKey = 'name',
    this.chipsFallbackKey,
    this.chipsClassId,
    this.reorder = false,
    this.modeSelect = false,
  });

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  late Future<List<DbRow>> _future = _load();
  List<DbRow> _chips = [];
  String? _chipSel;

  // Kis row ka kaun sa chip. Purani rows (category khali) type se jodi jati hain.
  String? _chipOf(DbRow r) {
    final v = r[widget.chipsKey];
    if (v != null && _chips.any((c) => '${c['id']}' == '$v')) return '$v';
    final fb = widget.chipsFallbackKey;
    if (v == null && fb != null) {
      final m = _chips.where((c) => c[fb] == r[fb]);
      if (m.isNotEmpty) return '${m.first['id']}';
    }
    return null;
  }

  String _effectiveChip(bool hasNone) {
    final ids = _chips.map((c) => '${c['id']}').toList();
    final cur = _chipSel;
    if (cur != null && (ids.contains(cur) || (cur == '_none' && hasNone))) {
      return cur;
    }
    return ids.isNotEmpty ? ids.first : '_none';
  }

  Widget _leading(DbRow r, int i) {
    final url = '${r['image_url'] ?? ''}'.trim();
    final avatar = CircleAvatar(child: Text('${i + 1}'));
    if (widget.chipsTable == null || !url.startsWith('http')) return avatar;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 64,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => avatar,
      ),
    );
  }

  Widget _chipBar(List<DbRow> all, String sel) {
    final counts = <String, int>{};
    for (final r in all) {
      final k = _chipOf(r) ?? '_none';
      counts[k] = (counts[k] ?? 0) + 1;
    }
    IconData iconOf(String? t) => t == 'video'
        ? Icons.play_circle_outline
        : t == 'pdf'
            ? Icons.quiz_outlined
            : Icons.menu_book_outlined;
    final types = <String, String?>{
      for (final c in _chips) '${c['id']}': c['type']?.toString()
    };
    final items = <MapEntry<String, String>>[
      for (final c in _chips)
        MapEntry('${c['id']}', '${c[widget.chipsLabelKey]}'),
      if ((counts['_none'] ?? 0) > 0) const MapEntry('_none', 'Bina category'),
    ];
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(iconOf(types[it.key]), size: 18),
                label: Text('${it.value} (${counts[it.key] ?? 0})'),
                selected: it.key == sel,
                onSelected: (_) => setState(() => _chipSel = it.key),
              ),
            ),
        ],
      ),
    );
  }

  Future<List<DbRow>> _load() async {
    if (widget.chipsTable != null) {
      final c = await db
          .from(widget.chipsTable!)
          .select()
          .order('sort_order', ascending: true);
      var cats = List<DbRow>.from(c);
      if (widget.chipsClassId != null) {
        final cc = await db
            .from('class_categories')
            .select('category_id, sort_order')
            .eq('class_id', widget.chipsClassId);
        final order = <String, num>{
          for (final r in cc) '${r['category_id']}': (r['sort_order'] ?? 0) as num
        };
        final mine = cats
            .where((x) =>
                order.containsKey('${x['id']}') && x['is_active'] != false)
            .toList();
        mine.sort((a, b) =>
            order['${a['id']}']!.compareTo(order['${b['id']}']!));
        // Is class ke liye kuch tick nahi hai to saari ON categories dikhao
        cats = mine.isNotEmpty
            ? mine
            : cats.where((x) => x['is_active'] != false).toList();
      }
      _chips = cats;
    }
    var q = db.from(widget.table).select();
    widget.filter.forEach((k, v) {
      q = q.eq(k, v);
    });
    for (final k in widget.nullFilter) {
      q = q.isFilter(k, null);
    }
    final data = await q.order('sort_order', ascending: true).order('id', ascending: true);
    return List<Db
