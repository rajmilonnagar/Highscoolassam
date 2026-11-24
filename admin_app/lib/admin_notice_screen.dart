import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sbn = Supabase.instance.client;

typedef _NRow = Map<String, dynamic>;

/// Admin app: notice / shubhkamna banner likhna, badalna, on-off, delete.
class NoticeManagerScreen extends StatefulWidget {
  const NoticeManagerScreen({super.key});

  @override
  State<NoticeManagerScreen> createState() => _NoticeManagerScreenState();
}

class _NoticeManagerScreenState extends State<NoticeManagerScreen> {
  List<_NRow> _items = [];
  List<_NRow> _mediums = [];
  bool _loading = true;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final r = await _sbn
          .from('notices')
          .select()
          .order('sort_order', ascending: true);
      final m = await _sbn
          .from('mediums')
          .select('id, name')
          .order('sort_order', ascending: true);
      if (!mounted) return;
      setState(() {
        _items = List<_NRow>.from(r);
        _mediums = List<_NRow>.from(m);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _edit([_NRow? item]) async {
    final title = TextEditingController(text: '${item?['title'] ?? ''}');
    final msg = TextEditingController(text: '${item?['message'] ?? ''}');
    final img = TextEditingController(text: '${item?['image_url'] ?? ''}');
    final link = TextEditingController(text: '${item?['link'] ?? ''}');
    final start = TextEditingController(text: '${item?['start_date'] ?? ''}');
    final end = TextEditingController(text: '${item?['end_date'] ?? ''}');
    final order = TextEditingController(
        text: '${item?['sort_order'] ?? (_items.length + 1)}');

    dynamic mediumId = item?['medium_id'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
        title: Text(item == null ? 'Naya notice' : 'Notice badlein'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                    labelText: 'Title (jaise: Shubho Durga Puja)'),
              ),
              TextField(
                controller: msg,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Chhota message (optional)'),
              ),
              TextField(
                controller: img,
                decoration: const InputDecoration(
                    labelText: 'Chhoti photo ka link (optional)'),
              ),
              TextField(
                controller: link,
                decoration: const InputDecoration(
                    labelText: 'Tap karne par khulne wala link (optional)'),
              ),
              TextField(
                controller: start,
                decoration: const InputDecoration(
                    labelText: 'Shuru date: 2026-10-18 (khali = abhi se)'),
              ),
              TextField(
                controller: end,
                decoration: const InputDecoration(
                    labelText: 'Aakhri date: 2026-10-25 (khali = hamesha)'),
              ),
              TextField(
                controller: order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Order (1,2,3...)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<dynamic>(
                isExpanded: true,
                value: mediumId,
                decoration: const InputDecoration(
                    labelText: 'Kis medium ke students ko dikhega'),
                items: [
                  const DropdownMenuItem<dynamic>(
                      value: null, child: Text('Sab medium')),
                  ..._mediums.map((m) => DropdownMenuItem<dynamic>(
                      value: m['id'], child: Text('${m['name']}'))),
                ],
                onChanged: (v) => setD(() => mediumId = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
      ),
    );

    if (ok != true) return;
    if (title.text.trim().isEmpty) {
      _snack('Title likhna zaroori hai');
      return;
    }
    final s = start.text.trim();
    final e = end.text.trim();
    if ((s.isNotEmpty && DateTime.tryParse(s) == null) ||
        (e.isNotEmpty && DateTime.tryParse(e) == null)) {
      _snack('Date aise likhein: 2026-10-18');
      return;
    }
    String? nz(String v) => v.trim().isEmpty ? null : v.trim();
    final data = {
      'title': title.text.trim(),
      'message': nz(msg.text),
      'image_url': nz(img.text),
      'link': nz(link.text),
      'start_date': nz(s),
      'end_date': nz(e),
      'sort_order': int.tryParse(order.text.trim()) ?? 0,
      'medium_id': mediumId,
    };
    try {
      if (item == null) {
        await _sbn.from('notices').insert(data);
      } else {
        await _sbn.from('notices').update(data).eq('id', item['id']);
      }
      _snack('Save ho gaya');
      _load();
    } catch (e) {
      _snack('Save nahi hua: $e');
    }
  }

  Future<void> _toggle(_NRow item, bool v) async {
    try {
      await _sbn.from('notices').update({'is_active': v}).eq('id', item['id']);
      _load();
    } catch (e) {
      _snack('Badla nahi: $e');
    }
  }

  Future<void> _delete(_NRow item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete karein?'),
        content: Text('"${item['title']}" hat jayega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nahi')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sbn.from('notices').delete().eq('id', item['id']);
      _load();
    } catch (e) {
      _snack('Delete nahi hua: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notice / Banner')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Naya notice'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Load nahi hua:\n$_err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Dobara try')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('Abhi koi notice nahi hai'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final n = _items[i];
        final active = n['is_active'] != false;
        final s = '${n['start_date'] ?? ''}';
        final e = '${n['end_date'] ?? ''}';
        final dates = (s.isEmpty && e.isEmpty)
            ? 'hamesha'
            : '${s.isEmpty ? 'abhi' : s}  se  ${e.isEmpty ? 'hamesha' : e}';
        final med = _mediums.where((m) => m['id'] == n['medium_id']);
        final medName = med.isEmpty ? 'Sab medium' : '${med.first['name']}';
        return ListTile(
          onTap: () => _edit(n),
          leading: const Icon(Icons.campaign),
          title: Text('${n['title']}'),
          subtitle: Text('$medName  ·  $dates${active ? '' : '  (OFF)'}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: active, onChanged: (v) => _toggle(n, v)),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(n),
              ),
            ],
          ),
        );
      },
    );
  }
}
