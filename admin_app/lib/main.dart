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
        F('category_id', 'Category (database se)', fromTable: 'categories', copy: {'type': 'type'}),
        F('title', 'Title (Book me neeche ka naam, jaise A for Apple)'),
        F('url', 'Link (video ya MCQ pdf)'),
        F('image_url', 'Photo 1 (video ka thumbnail / Book me BAAYEIN card)'),
        F('image_url2', 'Photo 2 (sirf Book me DAAYEIN card)'),
        F('body', 'Chhota text (Book me, optional)', multiline: true),
        F('sort_order', 'Order (1,2,3...)', number: true),
      ],
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
  const F(this.key, this.label,
      {this.multiline = false,
      this.number = false,
      this.options,
      this.fromTable,
      this.labelKey = 'name',
      this.copy = const {}});
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
        cats = cats
            .where((x) =>
                order.containsKey('${x['id']}') && x['is_active'] != false)
            .toList();
        cats.sort((a, b) =>
            order['${a['id']}']!.compareTo(order['${b['id']}']!));
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
    return List<DbRow>.from(data);
  }

  void _refresh() => setState(() => _future = _load());

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit([DbRow? row]) async {
    final ctrls = {
      for (final f in widget.fields)
        f.key: TextEditingController(
            text: row?[f.key] == null ? '' : '${row![f.key]}')
    };
    // Database se aane wale dropdown (jaise categories) pehle load karein
    final choices = <String, List<DbRow>>{};
    try {
      for (final f in widget.fields) {
        if (f.fromTable != null) {
          final data = await db
              .from(f.fromTable!)
              .select()
              .order('sort_order', ascending: true);
          choices[f.key] = List<DbRow>.from(data);
        }
      }
    } catch (e) {
      _msg('Dropdown load nahi hua: $e');
      return;
    }
    // Naye row me dropdown sirf is class ki categories dikhaye
    if (row == null &&
        widget.chipsClassId != null &&
        _chips.isNotEmpty &&
        choices.containsKey(widget.chipsKey)) {
      choices[widget.chipsKey] = List<DbRow>.from(_chips);
    }
    // Naye row me order apne aap agla number
    if (row == null) {
      final list = await _future;
      for (final f in widget.fields) {
        if (f.number && ctrls[f.key]!.text.isEmpty) {
          ctrls[f.key]!.text = '${list.length + 1}';
        }
        if (f.options != null && ctrls[f.key]!.text.isEmpty) {
          ctrls[f.key]!.text = f.options!.first;
        }
        if (f.fromTable != null &&
            ctrls[f.key]!.text.isEmpty &&
            (choices[f.key] ?? []).isNotEmpty) {
          ctrls[f.key]!.text = '${choices[f.key]!.first['id']}';
        }
        if (widget.chipsTable != null && f.key == widget.chipsKey) {
          final cur = _chipSel;
          if (cur != null &&
              cur != '_none' &&
              _chips.any((c) => '${c['id']}' == cur)) {
            ctrls[f.key]!.text = cur;
          }
        }
      }
    }
    if (!mounted) return;

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            title: Text(row == null ? 'Naya add karein' : 'Badlein'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: f.fromTable != null
                        ? DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: (choices[f.key] ?? <DbRow>[]).any(
                                    (r) => '${r['id']}' == ctrls[f.key]!.text)
                                ? ctrls[f.key]!.text
                                : null,
                            decoration: InputDecoration(
                                labelText: f.label,
                                border: const OutlineInputBorder()),
                            items: [
                              for (final r in choices[f.key] ?? <DbRow>[])
                                DropdownMenuItem(
                                    value: '${r['id']}',
                                    child: Text('${r[f.labelKey]}'))
                            ],
                            onChanged: (v) => ctrls[f.key]!.text = v ?? '',
                          )
                        : f.options != null
                            ? DropdownButtonFormField<String>(
                                value: ctrls[f.key]!.text,
                                decoration: InputDecoration(
                                    labelText: f.label,
                                    border: const OutlineInputBorder()),
                                items: [
                                  for (final o in f.options!)
                                    DropdownMenuItem(value: o, child: Text(o))
                                ],
                                onChanged: (v) => ctrls[f.key]!.text = v ?? '',
                              )
                            : TextField(
                                controller: ctrls[f.key],
                                keyboardType: f.multiline
                                    ? TextInputType.multiline
                                    : f.number
                                        ? TextInputType.number
                                        : TextInputType.text,
                                minLines: f.multiline ? 8 : 1,
                                maxLines: f.multiline ? null : 3,
                                decoration: InputDecoration(
                                    labelText: f.label,
                                    alignLabelWithHint: f.multiline,
                                    border: const OutlineInputBorder()),
                              ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;

    final vals = <String, dynamic>{};
    for (final f in widget.fields) {
      final t = ctrls[f.key]!.text.trim();
      if (f.number) {
        vals[f.key] = int.tryParse(t) ?? 0;
      } else if (f.fromTable != null) {
        vals[f.key] = t.isEmpty ? null : (int.tryParse(t) ?? t);
        final sel = (choices[f.key] ?? <DbRow>[]).where((r) => '${r['id']}' == t);
        if (sel.isNotEmpty) {
          f.copy.forEach((from, to) => vals[to] = sel.first[from]);
        }
      } else {
        vals[f.key] = t.isEmpty ? null : t;
      }
    }
    if (vals[widget.titleKey] == null) {
      _msg('Naam / title khali nahi ho sakta');
      return;
    }

    try {
      if (row == null) {
        await db.from(widget.table).insert({...widget.filter, ...vals});
      } else {
        await db.from(widget.table).update(vals).eq('id', row['id']);
      }
      _msg('Save ho gaya');
      _refresh();
    } catch (e) {
      _msg('Save nahi hua: $e');
    }
  }

  Future<void> _bulkAdd() async {
    final ctrl = TextEditingController();
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            title: const Text('Ek saath kai add karein'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add'),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                      'Har naam alag line me likhein ya paste karein. Order apne aap 1,2,3... lagega.'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Pehla naam\nDusra naam\nTeesra naam'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final names = ctrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (names.isEmpty) return;
    try {
      final list = await _future;
      var n = list.length;
      final rows = <Map<String, dynamic>>[
        for (final name in names)
          {...widget.filter, widget.titleKey: name, 'sort_order': ++n}
      ];
      await db.from(widget.table).insert(rows);
      _msg('${names.length} add ho gaye');
      _refresh();
    } catch (e) {
      _msg('Save nahi hua: $e');
    }
  }

  Future<void> _delete(DbRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete karein?'),
        content: Text(
            '"${row[widget.titleKey]}" hat jayega. Iske andar ka sab data bhi hat jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nahi')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Haan, delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await db.from(widget.table).delete().eq('id', row['id']);
      _refresh();
    } catch (e) {
      _msg('Delete nahi hua: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.bulk)
            IconButton(
              tooltip: 'Ek saath kai add karein',
              icon: const Icon(Icons.playlist_add),
              onPressed: _bulkAdd,
            ),
          if (widget.isRoot)
            PopupMenuButton<String>(
              tooltip: 'Categories / Notice',
              icon: const Icon(Icons.tune),
              onSelected: (v) {
                final Widget page = v == 'cat'
                    ? const CategoryManagerScreen()
                    : v == 'cls'
                        ? const ClassCategorySetupScreen()
                        : const NoticeManagerScreen();
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => page));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'cat', child: Text('Categories')),
                PopupMenuItem(
                    value: 'cls', child: Text('Class ke hisab se categories')),
                PopupMenuItem(value: 'notice', child: Text('Notice / Banner')),
              ],
            ),
          if (widget.isRoot)
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: () => db.auth.signOut(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: FutureBuilder<List<DbRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Data nahi aaya:\n${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _refresh, child: const Text('Dobara try karein')),
                  ],
                ),
              ),
            );
          }
          final all = snap.data ?? [];
          if (all.isEmpty && widget.chipsTable == null) {
            return const Center(child: Text('Abhi kuch nahi hai. Neeche Add dabayein.'));
          }
          final hasNone = all.any((r) => _chipOf(r) == null);
          final sel = _effectiveChip(hasNone);
          final rows = widget.chipsTable == null
              ? all
              : all.where((r) => (_chipOf(r) ?? '_none') == sel).toList();
          final Widget list = rows.isEmpty
              ? const Center(
                  child: Text('Is category me abhi kuch nahi hai. Neeche Add dabayein.'))
              : ListView.builder(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final sub = widget.subtitleKey == null
                  ? ''
                  : '${r[widget.subtitleKey] ?? ''}';
              return ListTile(
                leading: _leading(r, i),
                title: Text('${r[widget.titleKey] ?? ''}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: sub.isEmpty ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: widget.child == null
                    ? () => _edit(r)
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => widget.child!(r)),
                        ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.extra != null)
                      IconButton(
                        tooltip: widget.extraTooltip,
                        icon: Icon(widget.extraIcon, color: Colors.indigo),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => widget.extra!(r)),
                        ),
                      ),
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(r)),
                    IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(r)),
                  ],
                ),
              );
            },
          );
          if (widget.chipsTable == null) return list;
          return Column(
            children: [
              _chipBar(all, sel),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}
