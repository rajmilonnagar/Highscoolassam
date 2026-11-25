// Ye file main.dart ka hissa (part) hai, isliye iska apna import nahi hai.
// main.dart me imports ke neeche ye line honi chahiye:  part 'color_rows.dart';
part of 'main.dart';

// Har row ka alag halka rang (order ke hisab se ghoomta hai)
const List<Color> _kRowBg = [
  Color(0xFFFFF7E0),
  Color(0xFFE8F5E9),
  Color(0xFFFDECEA),
  Color(0xFFE3F2FD),
  Color(0xFFF3E8FD),
  Color(0xFFFFF3E0),
  Color(0xFFE0F7FA),
];

/// Medium / Subject / Chapter list: rangeen rows, baayein badge, daayein chevron,
/// dabane par halka sa dabne ka effect.
///  badge: 'symbol' = naam ka apna akshar (Medium ke liye, internet nahi chahiye)
///         'photo'  = photo; photo na ho (ya load ho rahi ho) to number ya icon
///  bgColor / headColor / titleLow: admin ke "App Design" se aate hain (khali = purana look)
class ColorRowsScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<List<DbRow>> Function() loader;
  final void Function(BuildContext context, DbRow item) onTap;
  final String badge;
  final bool numbered; // photo na ho to chapter ka number dikhao
  final IconData fallbackIcon;
  final bool showBanner;
  final DbRow? bannerMedium;
  final Color? bgColor;
  final Color? headColor;
  final bool titleLow; // true: title header me nahi, list ke upar dikhe

  const ColorRowsScreen({
    super.key,
    required this.title,
    required this.loader,
    required this.onTap,
    this.subtitle,
    this.badge = 'photo',
    this.numbered = false,
    this.fallbackIcon = Icons.menu_book,
    this.showBanner = false,
    this.bannerMedium,
    this.bgColor,
    this.headColor,
    this.titleLow = false,
  });

  @override
  State<ColorRowsScreen> createState() => _ColorRowsScreenState();
}

class _ColorRowsScreenState extends State<ColorRowsScreen> {
  late Future<List<DbRow>> _future = widget.loader();

  void _retry() => setState(() => _future = widget.loader());

  Color get _head => widget.headColor ?? kBrand;

  Widget _heading() {
    final dark = (widget.bgColor ?? kBg).computeLuminance() < 0.4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      child: Text(
        widget.title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : const Color(0xFF1F2937),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.bgColor,
      appBar: AppBar(
        title: widget.titleLow ? null : Text(widget.title),
        backgroundColor: _head,
        foregroundColor: Colors.white,
        bottom: widget.subtitle == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(widget.subtitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ),
      ),
      body: Column(
        children: [
          if (widget.showBanner) NoticeBanner(medium: widget.bannerMedium),
          Expanded(
            child: FutureBuilder<List<DbRow>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator(color: kBrand));
                }
                if (snap.hasError) {
                  return _Message(
                    text: 'Data load nahi hua. Internet check karein.',
                    onRetry: _retry,
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return _Message(text: 'Abhi yahan kuch nahi hai.', onRetry: _retry);
                }
                final extra = widget.titleLow ? 1 : 0;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                  itemCount: items.length + extra,
                  itemBuilder: (context, i) {
                    if (widget.titleLow && i == 0) return _heading();
                    final k = i - extra;
                    return _row(context, k, items[k]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i, DbRow item) {
    final name = '${item['name'] ?? ''}';
    final sub = '${item['subtitle'] ?? ''}'.trim();
    return _PressRow(
      color: _kRowBg[i % _kRowBg.length],
      onTap: () => widget.onTap(context, item),
      child: Row(
        children: [
          _badge(i, item, name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                      height: 1.3),
                ),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF4B5563)),
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF1F2937)),
        ],
      ),
    );
  }

  Widget _badge(int i, DbRow item, String name) {
    final bc = _head;
    Widget circle(Widget child) => Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: child,
        );

    // Medium: naam ka apna akshar (database ke `symbol` se, khali ho to naam ka pehla akshar)
    if (widget.badge == 'symbol') {
      var sym = '${item['symbol'] ?? ''}'.trim();
      if (sym.isEmpty && name.trim().isNotEmpty) {
        sym = String.fromCharCode(name.trim().runes.first);
      }
      return circle(Text(sym,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, color: bc)));
    }

    // Photo: na ho ya load ho rahi ho to number / icon dikhta hai (khali dabba nahi)
    final fallback = widget.numbered
        ? circle(Text('${i + 1}',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: bc)))
        : circle(Icon(widget.fallbackIcon, color: bc, size: 26));
    final img = imageUrl(item['image_url'] as String?);
    if (img.isEmpty) return fallback;
    return ClipOval(
      child: SizedBox(
        width: 52,
        height: 52,
        child: CachedNetworkImage(
          imageUrl: img,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

/// Rangeen card: dabate hi thoda dabta hai aur ripple dikhta hai
class _PressRow extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  const _PressRow({required this.color, required this.onTap, required this.child});

  @override
  State<_PressRow> createState() => _PressRowState();
}

class _PressRowState extends State<_PressRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Material(
          color: widget.color,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _down = v),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
