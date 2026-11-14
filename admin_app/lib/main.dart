import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      fields: _nameImgOrder,
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
      child: (ch) => contentsScreen(ch),
      bulk: true,
      extraIcon: Icons.account_tree,
      extraTooltip: 'Sub-chapters (chhote chapter)',
      extra: (ch) => chaptersScreen(s, ch),
    );

Widget contentsScreen(DbRow ch) => TableScreen(
      title: '${ch['name']} - Content',
      table: 'contents',
      filter: {'chapter_id': ch['id']},
      fields: const [
        F('type', 'Type', options: ['video', 'pdf', 'qa']),
        F('title', 'Title (Q&A me sawaal)'),
        F('url', 'Link (video ya pdf)'),
        F('image_url', 'Photo link (optional)'),
        F('body', 'Jawab (sirf Q&A me)', multiline: true),
        F('sort_order', 'Order (1,2,3...)', number: true),
      ],
      titleKey: 'title',
      subtitleKey: 'type',
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
  const F(this.key, this.label,
      {this.multiline = false, this.number = false, this.options});
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
  });

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  late Future<List<DbRow>> _future = _load();

  Future<List<DbRow>> _load() async {
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
      }
    }
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row == null ? 'Naya add karein' : 'Badlein'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: f.options != null
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
                          keyboardType:
                              f.number ? TextInputType.number : TextInputType.text,
                          minLines: f.multiline ? 3 : 1,
                          maxLines: f.multiline ? 6 : 2,
                          decoration: InputDecoration(
                              labelText: f.label,
                              border: const OutlineInputBorder()),
                        ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    final vals = <String, dynamic>{};
    for (final f in widget.fields) {
      final t = ctrls[f.key]!.text.trim();
      if (f.number) {
        vals[f.key] = int.tryParse(t) ?? 0;
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ek saath kai add karein'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Har naam alag line me likhein ya paste karein. Order apne aap 1,2,3... lagega.'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Pehla naam\nDusra naam\nTeesra naam'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
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
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return const Center(child: Text('Abhi kuch nahi hai. Neeche Add dabayein.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final sub = widget.subtitleKey == null
                  ? ''
                  : '${r[widget.subtitleKey] ?? ''}';
              return ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text('${r[widget.titleKey] ?? ''}'),
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
        },
      ),
    );
  }
}
