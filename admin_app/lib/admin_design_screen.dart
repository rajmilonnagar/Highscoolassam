import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase SQL Editor me ek baar ye chalana (card ka rang save karne ke liye):
//   alter table app_design add column if not exists card_color text default 'multi';

final _dsb = Supabase.instance.client;

const List<List<String>> _bgOptions = [
  ['#F8F9FA', 'Abhi wala'],
  ['#FFF4E5', 'Halka naranji'],
  ['#EAF6EE', 'Halka hara'],
  ['#E8F1FB', 'Halka neela'],
  ['#F6ECF8', 'Halka jamuni'],
  ['#FDEEF2', 'Halka gulabi'],
  ['#1F2430', 'Gehra (dark)'],
];

const List<List<String>> _brOptions = [
  ['#AD1457', '#E91E63', 'Abhi wala'],
  ['#D81B60', '#FF4081', 'Magenta'],
  ['#C2185B', '#F06292', 'Gulabi'],
  ['#6A1B9A', '#AB47BC', 'Jamuni'],
  ['#283593', '#5C6BC0', 'Neela-jamuni'],
  ['#1565C0', '#42A5F5', 'Neela'],
  ['#00796B', '#4DB6AC', 'Hara'],
  ['#E65100', '#FF9800', 'Naranji'],
  ['#37474F', '#78909C', 'Grey'],
];

// 'multi' = har row ka alag halka rang (abhi wala look)
const List<List<String>> _cardOptions = [
  ['multi', 'Rangeen (abhi wala)'],
  ['#FFFFFF', 'Safed'],
  ['#FFF7E0', 'Halka peela'],
  ['#E8F5E9', 'Halka hara'],
  ['#E3F2FD', 'Halka neela'],
  ['#F3E8FD', 'Halka jamuni'],
  ['#FDECEA', 'Halka gulabi'],
];

Color _hex(String h) {
  var s = h.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFF000000);
}

/// App Design: yahan jo chunenge, student app me wahi dikhega.
class DesignScreen extends StatefulWidget {
  const DesignScreen({super.key});

  @override
  State<DesignScreen> createState() => _DesignScreenState();
}

class _DesignScreenState extends State<DesignScreen> {
  String _bg = '#F8F9FA';
  String _br = '#AD1457';
  String _br2 = '#E91E63';
  String _card = 'multi';
  bool _low = false;
  bool _loading = true;
  bool _saving = false;
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
      final r =
          await _dsb.from('app_design').select().eq('id', 1).maybeSingle();
      if (r != null) {
        _bg = '${r['bg_color'] ?? _bg}';
        _br = '${r['brand_color'] ?? _br}';
        _br2 = '${r['brand_color2'] ?? _br2}';
        final c = '${r['card_color'] ?? ''}'.trim();
        _card = c.isEmpty ? 'multi' : c;
        _low = r['title_low'] == true;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _dsb.from('app_design').upsert({
        'id': 1,
        'bg_color': _bg,
        'brand_color': _br,
        'brand_color2': _br2,
        'card_color': _card,
        'title_low': _low,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _snack('Save ho gaya. Student app dobara kholne par badlav dikhega.');
    } catch (e) {
      _snack('Save nahi hua: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _swatch({
    required bool on,
    required VoidCallback onTap,
    Color? color,
    Gradient? gradient,
    String tip = '',
  }) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            shape: BoxShape.circle,
            border: Border.all(
                color: on ? Colors.black87 : Colors.black26,
                width: on ? 3 : 1),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  // Card ka rang: 'multi' ho to row ka apna rang, warna chuna hua ek rang
  Color _cardColor(Color rowDefault) =>
      _card == 'multi' ? rowDefault : _hex(_card);

  // Student app ke Select Medium screen ka chhota nakal (live preview)
  Widget _preview() {
    final bg = _hex(_bg);
    final br = _hex(_br);
    final br2 = _hex(_br2);
    final dark = bg.computeLuminance() < 0.4;
    final titleColor = dark ? Colors.white : const Color(0xFF1F2937);
    final base = _card == 'multi' ? Colors.white : _hex(_card);
    const rows = [
      [Color(0xFFFFF7E0), 'অ', 'অসমীয়া মাধ্যম'],
      [Color(0xFFE8F5E9), 'ব', 'বাংলা মাধ্যম'],
      [Color(0xFFFDECEA), 'ब', 'Bodo Medium'],
      [Color(0xFFE3F2FD), 'A', 'English Medium'],
      [Color(0xFFF3E8FD), 'ଓ', 'Odia Medium'],
    ];
    Widget title() => Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
          child: Text('Select Medium',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: titleColor)),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        color: bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: br,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_low)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('Select Medium',
                          style: TextStyle(fontSize: 24, color: Colors.white)),
                    ),
                  const Center(
                    child: Text('ID: BP2A.2... | Free Trial: 14 Days Left',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: base, borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      children: [
                        CircleAvatar(
                            radius: 24,
                            backgroundColor: Color(0xFFE9E1FB),
                            child: Text('🌇')),
                        Sized
