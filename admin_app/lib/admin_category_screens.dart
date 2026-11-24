import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sbc = Supabase.instance.client;

// type batata hai ki student app me category kaise dikhegi
const Map<String, String> _kTypes = {
  'video': 'video (bade video cards)',
  'pdf': 'pdf (PDF / MCQ list)',
  'qa': 'qa (photo / sawal-jawab cards)',
};

typedef _Row = Map<String, dynamic>;

// ---------------------------------------------------------------------------
// 1) Category Manager: naam, type, photo link, order, on/off, delete
// ---------------------------------------------------------------------------
class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  List<_Row> _items = [];
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
      final r = await _sbc
          .from('categories')
          .select()
          .order('sort_order', ascending: true);
      if (!mounted) return;
      setState(() {
        _items = List<_Row>.from(r);
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

  Future<void> _edit([_Row? item]) async {
    final name = TextEditingController(text: '${item?['name'] ?? ''}');
    final img = TextEditingController(text: '${item?['image_url'] ?? ''}');
    final order = TextEditingController(
        text: '${item?['sort_order'] ?? (_items.length + 1)}');
    String type = (item?['type'] ?? 'qa').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(item == null ? 'Naya category' : 'Category badlein'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Category ka naam'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _kTypes.containsKey(type) ? type : 'qa',
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _kTypes.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setD(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: img,
                  decoration: const InputDecoration(
                      labelText: 'Chip ki chhoti photo ka link (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Order (1,2,3...)'),
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
    final n = name.text.trim();
    if (n.isEmpty) {
      _snack('Naam likhna zaroori hai');
      return;
    }
    final data = {
      'name': n,
      'type': type,
      'image_url': img.text.trim().isEmpty ? null : img.text.trim(),
      'sort_order': int.tryParse(order.text.trim()) ?? 0,
    };
    try {
      if (item == null) {
        await _sbc.from('categories').insert(data);
      } else {
        await _sbc.from('categories').update(data).eq('id', item['id']);
      }
      _snack('Save ho gaya');
      _load();
    } catch (e) {
      _snack('Save nahi hua: $e');
    }
  }

  Future<void> _toggle(_Row item, bool v) async {
    try {
      await _sbc
          .from('categories')
          .update({'is_active': v}).eq('id', item['id']);
      _load();
    } catch (e) {
      _snack('Badla nahi: $e');
    }
  }

  Future<void> _delete(_Row item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete karein?'),
        content: Text('"${item['name']}" hamesha ke liye hat jayega.'),
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
      await _sbc.from('categories').delete().eq('id', item['id']);
      _load();
    } catch (e) {
      _snack('Delete nahi hua. Is category me content juda ho sakta hai, '
          'to delete ki jagah OFF kar dein.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Naya category'),
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
      return const Center(child: Text('Abhi koi category nahi hai'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final c = _items[i];
        final active = c['is_active'] != false;
        return ListTile(
          onTap: () => _edit(c),
          leading: CircleAvatar(child: Text('${c['sort_order'] ?? ''}')),
          title: Text('${c['name']}'),
          subtitle: Text('${c['type']}${active ? '' : '  (hidden)'}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(value: active, onChanged: (v) => _toggle(c, v)),
              IconButton(
                icon: const Icon(Icons.
