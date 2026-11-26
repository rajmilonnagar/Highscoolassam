
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:google_fonts/google_fonts.dart';
import 'splash_screen.dart';

part 'chip_content_screen.dart';
part 'notice_banner.dart';
part 'color_rows.dart';
part 'app_design.dart';

// App ke default rang (internet na ho ya admin ne kuch na chuna ho to ye chalte hain).
// Admin ka chuna hua rang AppDesign.brand / AppDesign.bg me aata hai (app_design.dart).
const Color kBrand = Color(0xFFAD1457);
const Color kBg = Color(0xFFF8F9FA);
const Color kGrey = Color(0xFF6B7280);
const Color kThumbBg = Color(0xFFF1F3F5);

/// Card: halki parchhai, 16 round kone. Rang admin ke "Card ka rang" se.
Card appCard({required Widget child, EdgeInsetsGeometry? margin}) => Card(
      color: AppDesign.cardBase,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black26,
      margin: margin ?? EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: child,
    );

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase initialize karein (apni credentials yahan dalein)
  await Supabase.initialize(
    url: 'https://ymiakzzapyhybtoumtbx.supabase.co',
    anonKey: 'PASTE_SUPABASE_ANON_KEY_HERE',
  );
  await AppDesign.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Highschool Assam',
      theme: _buildTheme(),
      home: const SplashScreen(next: DeviceCheckScreen()),
    );
  }
}

// 1. Device Verification & Trial Check Screen
class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({super.key});

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends State<DeviceCheckScreen> {
  bool isLoading = true;
  bool isAccessAllowed = false;
  String deviceId = '';
  int remainingDays = 30;

  @override
  void initState() {
    super.initState();
    verifyDeviceAndTrial();
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown';
    }
    return 'unknown_device';
  }

  Future<void> verifyDeviceAndTrial() async {
    try {
      deviceId = await _getDeviceId();
      final supabase = Supabase.instance.client;

      // Check if device exists in database
      final response = await supabase
          .from('devices')
          .select()
          .eq('device_id', deviceId)
          .maybeSingle();

      if (response == null) {
        // Naya device hai, register karein
        await supabase.from('devices').insert({
          'device_id': deviceId,
          'bill_paid': false,
        });
        setState(() {
          isAccessAllowed = true;
          remainingDays = 30;
          isLoading = false;
        });
      } else {
        // Purana device hai, din calculate karein
        final createdAt = DateTime.parse(response['created_at']);
        final difference = DateTime.now().difference(createdAt).inDays;
        bool billPaid = response['bill_paid'] ?? false;

        int daysLeft = 30 - difference;

        if (billPaid || daysLeft > 0) {
          setState(() {
            isAccessAllowed = true;
            remainingDays = daysLeft > 0 ? daysLeft : 0;
            isLoading = false;
          });
        } else {
          // Trial khatam aur bill pay nahi hua
          setState(() {
            isAccessAllowed = false;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      // Error handling
      setState(() {
        isLoading = false;
        isAccessAllowed = true; // Offline/Error fallback
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAccessAllowed) {
      // Pay Bill Screen
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 80, color: AppDesign.brand),
                const SizedBox(height: 20),
                const Text(
                  "Your 30-day free trial has expired!",
                  style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Please pay ₹10 to continue accessing your studies.",
                  style: TextStyle(color: kGrey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.brand,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    // Yahan payment gateway trigger hoga
                  },
                  child: const Text("Pay ₹10 Now",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Access granted -> Medium Selection Screen
    return MediumSelectionScreen(
        deviceId: deviceId, remainingDays: remainingDays);
  }
}

// ---------------------------------------------------------------------------
// Helpers: Google Drive / Bunny.net links ko app ke kaam layak URL me badalna
// ---------------------------------------------------------------------------

String? _driveId(String url) {
  if (!url.contains('drive.google.com') && !url.contains('docs.google.com')) {
    return null;
  }
  final m = RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(url) ??
      RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
  return m?.group(1);
}

/// Google Drive photo link -> seedha image URL. Normal link ho to waisa hi.
String imageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  url = url.trim();
  final id = _driveId(url);
  if (id != null) return 'https://lh3.googleusercontent.com/d/$id=w600';
  return url;
}

/// Bunny Stream video. Teeno me se koi bhi format chalega:
///  1) poora embed link:  https://iframe.mediadelivery.net/embed/LIB/VIDEO
///  2) chhota:            LIB/VIDEO
///  3) koi aur video link (YouTube etc.) as it is
String videoUrl(String url) {
  url = url.trim();
  if (!url.startsWith('http')) {
    url = 'https://iframe.mediadelivery.net/embed/$url';
  }
  if (url.contains('mediadelivery.net') && !url.contains('?')) {
    url = '$url?autoplay=true&preload=true';
  }
  return url;
}

/// YouTube link ya 11 akshar ki video ID se ID nikalta hai, nahi mile to null.
String? youtubeId(String url) {
  url = url.trim();
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(url)) return url;
  final m = RegExp(
          r'(?:youtu\.be/|youtube\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/|live/))([A-Za-z0-9_-]{11})')
      .firstMatch(url);
  return m?.group(1);
}

/// PDF: Google Drive link ho to /preview, Bunny/koi direct .pdf link ho to Google viewer.
String pdfUrl(String url) {
  url = url.trim();
  final low = url.toLowerCase();
  if (low.endsWith('.txt') || low.endsWith('.json')) return url;
  final id = _driveId(url);
  if (id != null) return 'https://drive.google.com/file/d/$id/preview';
  return 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}';
}

final _db = Supabase.instance.client;

/// true: YouTube video seedha watch page se chalta hai (embed error nahi aata).
/// false: YouTube embed player (abhi 152-4 error de raha hai).
const bool kYoutubeWatchPage = true;

// ---------------------------------------------------------------------------
// Generic grid screen: naam + photo wali kisi bhi list ke liye (Class list)
// ---------------------------------------------------------------------------

typedef DbRow = Map<String, dynamic>;

class ItemGridScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<List<DbRow>> Function() loader;
  final void Function(BuildContext context, DbRow item) onTap;
  final IconData fallbackIcon;
  final int columns;
  final double aspect;
  final bool listStyle; // true: ek ke neeche ek, number + photo + naam wali list
  final bool showBanner; // true: upar greeting + notice banner
  final DbRow? bannerMedium; // medium chunne ke baad wali screen par medium ki row

  const ItemGridScreen({
    super.key,
    required this.title,
    required this.loader,
    required this.onTap,
    this.subtitle,
    this.fallbackIcon = Icons.menu_book,
    this.columns = 2,
    this.aspect = 0.9,
    this.listStyle = false,
    this.showBanner = false,
    this.bannerMedium,
  });

  @override
  State<ItemGridScreen> createState() => _ItemGridScreenState();
}

class _ItemGridScreenState extends State<ItemGridScreen> {
  late Future<List<DbRow>> _future = widget.loader();

  void _retry() => setState(() => _future = widget.loader());

  Widget _thumb(DbRow item) {
    final img = imageUrl(item['image_url'] as String?);
    final fallback = Container(
      color: kThumbBg,
      child: Center(
          child: Icon(widget.fallbackIcon, size: 40, color: AppDesign.brand)),
    );
    if (img.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: img,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(color: kThumbBg),
      errorWidget: (_, __, ___) => fallback,
    );
  }

  // Grid card: upar photo, neeche naam
  Widget _gridCard(BuildContext context, DbRow item) {
    return appCard(
      child: InkWell(
        onTap: () => widget.onTap(context, item),
        child: Column(
          children: [
            Expanded(child: SizedBox(width: double.infinity, child: _thumb(item))),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                (item['name'] ?? '') as String,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1F2937)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // List row: number + photo + naam
  Widget _listRow(BuildContext context, int i, DbRow item) {
    return appCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => widget.onTap(context, item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppDesign.brand)),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 56, height: 56, child: _thumb(item)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (item['name'] ?? '') as String,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF1F2937)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF1F2937)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppDesign.brand,
        foregroundColor: Colors.white,
        bottom: widget.subtitle == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(widget.subtitle!,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Message(
                    text: 'Data load nahi hua. Internet check karein.',
                    onRetry: _retry,
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return _Message(
                      text: 'Abhi yahan kuch nahi hai.', onRetry: _retry);
                }
                if (widget.listStyle) {
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _listRow(context, i, items[i]),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: widget.aspect,
                  ),
                  itemBuilder: (context, i) => _gridCard(context, items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _Message({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(color: kGrey, fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppDesign.brand, foregroundColor: Colors.white),
            onPressed: onRetry,
            child: const Text('Dobara try karein'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Medium -> 3. Class -> 4. Subject -> 5. Chapter -> 6. Content
// ---------------------------------------------------------------------------

class MediumSelectionScreen extends StatelessWidget {
  final String deviceId;
  final int remainingDays;
  const MediumSelectionScreen(
      {super.key, required this.deviceId, required this.remainingDays});

  @override
  Widget build(BuildContext context) {
    final shortId = deviceId.length > 6 ? deviceId.substring(0, 6) : deviceId;
    return ColorRowsScreen(
      title: 'Select Medium',
      subtitle: 'ID: $shortId... | Free Trial: $remainingDays Days Left',
      fallbackIcon: Icons.school,
      badge: 'symbol',
      showBanner: true,
      bgColor: AppDesign.bg,
      headColor: AppDesign.brand,
      titleLow: AppDesign.titleLow,
      loader: () async => List<DbRow>.from(
          await _db.from('mediums').select().order('sort_order', ascending: true)),
      onTap: (context, medium) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClassListScreen(medium: medium)),
      ),
    );
  }
}

class ClassListScreen extends StatelessWidget {
  final DbRow medium;
  const ClassListScreen({super.key, required this.medium});

  @override
  Widget build(BuildContext context) {
    return ItemGridScreen(
      title: '${medium['name']} - Classes',
      fallbackIcon: Icons.class_,
      aspect: 1.1,
      showBanner: true,
      bannerMedium: medium,
      loader: () async => List<DbRow>.from(
          await _db.from('classes').select().order('sort_order', ascending: true)),
      onTap: (context, cls) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SubjectListScreen(medium: medium, cls: cls)),
      ),
    );
  }
}

class SubjectListScreen extends StatelessWidget {
  final DbRow medium;
  final DbRow cls;
  const SubjectListScreen({super.key, required this.medium, required this.cls});

  @override
  Widget build(BuildContext context) {
    return SubjectGridScreen(
      title: '${cls['name']} - Subjects',
      fallbackIcon: Icons.book,
      loader: () async {
        final subs = List<DbRow>.from(await _db
            .from('subjects')
            .select()
            .eq('medium_id', medium['id'])
            .eq('class_id', cls['id'])
            .order('sort_order', ascending: true));
        // Har subject ke neeche "N Chapters" (ginti na mile to waisa hi chhod do)
        if (subs.isNotEmpty) {
          try {
            final ch = await _db
                .from('chapters')
                .select('subject_id')
                .inFilter('subject_id', subs.map((s) => s['id']).toList())
                .isFilter('parent_id', null);
            final counts = <dynamic, int>{};
            for (final c in ch) {
              counts[c['subject_id']] = (counts[c['subject_id']] ?? 0) + 1;
            }
            for (final s in subs) {
              final n = counts[s['id']] ?? 0;
              if (n > 0) s['subtitle'] = '$n Chapters';
            }
          } catch (_) {}
        }
        return subs;
      },
      onTap: (context, subject) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChapterListScreen(subject: subject)),
      ),
    );
  }
}

/// Subject: ek line me 3 card, upar icon / photo, neeche naam
class SubjectGridScreen extends StatefulWidget {
  final String title;
  final Future<List<DbRow>> Function() loader;
  final void Function(BuildContext context, DbRow item) onTap;
  final IconData fallbackIcon;
  const SubjectGridScreen({
    super.key,
    required this.title,
    required this.loader,
    required this.onTap,
    this.fallbackIcon = Icons.book,
  });

  @override
  State<SubjectGridScreen> createState() => _SubjectGridScreenState();
}

class _SubjectGridScreenState extends State<SubjectGridScreen> {
  late Future<List<DbRow>> _future = widget.loader();

  // (halka rang, gehra rang) har card ka alag
  static const List<List<Color>> _tints = [
    [Color(0xFFF3E8FD), Color(0xFF7E57C2)],
    [Color(0xFFE8F5E9), Color(0xFF2E7D32)],
    [Color(0xFFE3F2FD), Color(0xFF1565C0)],
    [Color(0xFFFFF3E0), Color(0xFFEF6C00)],
    [Color(0xFFFDECEA), Color(0xFFC62828)],
    [Color(0xFFFFF8E1), Color(0xFFF9A825)],
    [Color(0xFFE0F7FA), Color(0xFF00838F)],
  ];

  void _retry() => setState(() => _future = widget.loader());

  Widget _card(BuildContext context, int i, DbRow item) {
    final t = _tints[i % _tints.length];
    final img = imageUrl(item['image_url'] as String?);
    final sub = '${item['subtitle'] ?? ''}'.trim();
    final icon = Icon(widget.fallbackIcon, size: 30, color: t[1]);
    return Card(
      color: AppDesign.cardBase,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black26,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => widget.onTap(context, item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: t[0], borderRadius: BorderRadius.circular(20)),
                child: img.isEmpty
                    ? Center(child: icon)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Center(child: icon),
                          errorWidget: (_, __, ___) => Center(child: icon),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                '${item['name'] ?? ''}',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                    height: 1.25),
              ),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: kGrey)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppDesign.brand,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<DbRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, i) => _card(context, i, items[i]),
          );
        },
      ),
    );
  }
}

class ChapterListScreen extends StatelessWidget {
  final DbRow subject;
  final DbRow? parent; // sub-chapter list ke liye: upar wala chapter
  const ChapterListScreen({super.key, required this.subject, this.parent});

  @override
  Widget build(BuildContext context) {
    return ColorRowsScreen(
      title: parent == null ? '${subject['name']}' : '${parent!['name']}',
      fallbackIcon: Icons.menu_book,
      numbered: true,
      loader: () async {
        var q = _db.from('chapters').select().eq('subject_id', subject['id']);
        q = parent == null
            ? q.isFilter('parent_id', null)
            : q.eq('parent_id', parent!['id']);
        return List<DbRow>.from(await q.order('sort_order', ascending: true));
      },
      onTap: (context, chapter) async {
        // Agar is chapter ke andar chhote chapters hain to wo dikhao, nahi to content
        List kids = [];
        try {
          kids = await _db
              .from('chapters')
              .select('id')
              .eq('parent_id', chapter['id'])
              .limit(1);
        } catch (_) {}
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => kids.isNotEmpty
                ? ChapterListScreen(subject: subject, parent: chapter)
                : ChipContentScreen(chapter: chapter, subject: subject),
          ),
        );
      },
    );
  }
}

// Content: Videos / MCQ / Book (purani 3-tab screen; ab ChipContentScreen use hoti hai)

class ContentScreen extends StatefulWidget {
  final DbRow chapter;
  const ContentScreen({super.key, required this.chapter});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  late Future<List<DbRow>> _future = _load();

  Future<List<DbRow>> _load() async => List<DbRow>.from(await _db
      .from('contents')
      .select()
      .eq('chapter_id', widget.chapter['id'])
      .order('sort_order', ascending: true));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.chapter['name']}'),
          backgroundColor: AppDesign.brand,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.video_library), text: 'Videos'),
              Tab(icon: Icon(Icons.quiz), text: 'MCQ'),
              Tab(icon: Icon(Icons.menu_book), text: 'Book'),
            ],
          ),
        ),
        body: FutureBuilder<List<DbRow>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _Message(
                  text: 'Data load nahi hua.',
                  onRetry: () => setState(() => _future = _load()));
            }
            final all = snap.data ?? [];
            List<DbRow> of(String t) => all.where((r) => r['type'] == t).toList();
            return TabBarView(children: [
              _FileList(
                  items: of('video'),
                  icon: Icons.play_circle_fill,
                  empty: 'Videos jald aayenge',
                  isVideo: true,
                  open: (r) => r['url'] as String),
              _FileList(
                  items: of('pdf'),
                  icon: Icons.quiz,
                  empty: 'MCQ jald aayenge',
                  open: (r) => pdfUrl(r['url'] as String)),
              _QaList(items: of('qa')),
            ]);
          },
        ),
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  final List<DbRow> items;
  final IconData icon;
  final String empty;
  final String Function(DbRow) open;
  final bool isVideo;
  const _FileList(
      {required this.items,
      required this.icon,
      required this.empty,
      required this.open,
      this.isVideo = false});

  // Photo: pehle aapka diya image_url, nahi to YouTube ka apna thumbnail, nahi to icon
  Widget _img(DbRow r, double iconSize) {
    var img = imageUrl(r['image_url'] as String?);
    if (img.isEmpty && isVideo) {
      final yt = youtubeId((r['url'] ?? '').toString());
      if (yt != null) img = 'https://img.youtube.com/vi/$yt/hqdefault.jpg';
    }
    final fallback = Container(
      color: kThumbBg,
      child: Center(child: Icon(icon, color: AppDesign.brand, size: iconSize)),
    );
    if (img.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: img,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(color: kThumbBg),
      errorWidget: (_, __, ___) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
          child: Text(empty, style: const TextStyle(color: kGrey, fontSize: 18)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        // Video ke alawa (MCQ / pdf wali list) har link seedha card me load ho
        if (!isVideo) {
          return _AutoCard(
            title: '${r['title'] ?? ''}'.trim(),
            body: '${r['body'] ?? ''}'.trim(),
            url: '${r['url'] ?? ''}'.trim(),
          );
        }
        void openIt() => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => isVideo
                      ? VideoPlayerScreen(url: open(r))
                      : WebViewScreen(title: '${r['title']}', url: open(r))),
            );
        final title = Text(
          '${r['title']}',
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
        return appCard(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: InkWell(
            onTap: openIt,
            child: isVideo
                // Video: bada card, upar 16:9 photo, neeche title
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _img(r, 56),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 34),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        child: title,
                      ),
                    ],
                  )
                // PDF: chhota photo/icon baayein, title daayein
                : Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                              width: 72, height: 72, child: _img(r, 34)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: title),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _QaList extends StatelessWidget {
  final List<DbRow> items;
  const _QaList({required this.items});

  // Ek square card me photo (poori dikhe, kate nahi)
  Widget _pic(String? raw, {double ratio = 1}) {
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
                  placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 48, color: kGrey)),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('Book jald aayegi',
              style: TextStyle(color: kGrey, fontSize: 18)));
    }
    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      itemBuilder: (context, i) {
        final r = items[i];
        final title = '${r['title'] ?? ''}';
        final body = '${r['body'] ?? ''}';
        final hasPics = (r['image_url'] ?? '').toString().trim().isNotEmpty ||
            (r['image_url2'] ?? '').toString().trim().isNotEmpty;

        // Photo nahi hai: text + koi bhi link (pdf / drive / txt / json / photo) seedha load ho
        if (!hasPics) {
          return _AutoCard(
              title: title, body: body, url: '${r['url'] ?? ''}'.trim());
        }

        final p1 = '${r['image_url'] ?? ''}'.trim();
        final p2 = '${r['image_url2'] ?? ''}'.trim();

        // Dono photo ho to Double card (ek line me 2), ek hi ho to Single card (poori chaudai)
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
      },
    );
  }
}

// Video aur PDF dono isi me khulte hain

/// Card ke andar hi Drive / pdf / txt / json file live dikhti hai
class _InlineDoc extends StatefulWidget {
  final String title;
  final String url;
  final bool card; // false: sirf viewer (kisi bade card ke andar)
  const _InlineDoc({required this.title, required this.url, this.card = true});

  @override
  State<_InlineDoc> createState() => _InlineDocState();
}

class _InlineDocState extends State<_InlineDoc> {
  late final WebViewController _c = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.white)
    ..loadRequest(Uri.parse(widget.url));

  void _full() => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => WebViewScreen(
                title: widget.title.isEmpty ? 'File' : widget.title,
                url: widget.url)),
      );

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.68;
    final view = SizedBox(
      height: h,
      child: WebViewWidget(
        controller: _c,
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
      ),
    );
    if (!widget.card) {
      return Stack(
        children: [
          view,
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
      );
    }
    return appCard(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'Poori screen',
                  icon: Icon(Icons.open_in_full, color: AppDesign.brand),
                  onPressed: _full,
                ),
              ],
            ),
          ),
          view,
        ],
      ),
    );
  }
}

/// Ek card: title + text + us text/url ke andar ka har link apne aap load hokar dikhta hai
class _AutoCard extends StatelessWidget {
  final String title;
  final String body;
  final String url;
  const _AutoCard({required this.title, required this.body, required this.url});

  static final _re = RegExp(r'https?://[^\s]+');

  static bool _isImg(String u) {
    final l = u.toLowerCase().split('?').first;
    return l.endsWith('.jpg') ||
        l.endsWith('.jpeg') ||
        l.endsWith('.png') ||
        l.endsWith('.gif') ||
        l.endsWith('.webp') ||
        u.contains('googleusercontent.com');
  }

  static bool _isTxt(String u) =>
      u.toLowerCase().split('?').first.endsWith('.txt');

  Widget _link(String link) {
    // .txt link: question laal, answer neela, poori lambai (andar scroll nahi)
    if (_isTxt(link)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ColoredTxtView(url: link),
      );
    }
    if (_isImg(link)) {
      final img = imageUrl(link);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: img.isEmpty ? link : img,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            placeholder: (_, __) => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator())),
            errorWidget: (_, __, ___) => const SizedBox(
                height: 80, child: Center(child: Icon(Icons.broken_image))),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _InlineDoc(title: title, url: pdfUrl(link), card: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    final seen = <String>{};
    var last = 0;
    for (final m in _re.allMatches(body)) {
      final raw = m.group(0)!;
      final link = raw.replaceAll(RegExp(r'[).,;]+$'), '');
      final before = body.substring(last, m.start).trim();
      if (before.isNotEmpty) {
        parts.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SelectableText(before, style: const TextStyle(height: 1.5)),
        ));
      }
      seen.add(link);
      parts.add(_link(link));
      last = m.start + link.length;
    }
    final tail = body.substring(last).trim();
    if (tail.isNotEmpty) {
      parts.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SelectableText(tail, style: const TextStyle(height: 1.5)),
      ));
    }
    if (_re.hasMatch(url) && !seen.contains(url)) parts.add(_link(url));

    return appCard(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ...parts,
          ],
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  const WebViewScreen({super.key, required this.title, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _c = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.black)
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppDesign.brand,
        foregroundColor: Colors.white,
      ),
      body: WebViewWidget(controller: _c),
    );
  }
}

// Video: click karte hi full screen (landscape), back dabate hi chapter me wapas

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  const VideoPlayerScreen({super.key, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final WebViewController _c;
  bool _showSeek = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    if (_c.platform is AndroidWebViewController) {
      (_c.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    final yt = youtubeId(widget.url);
    if (yt != null && kYoutubeWatchPage) {
      // YouTube ka embed 152-4 error deta hai, isliye seedha watch page kholte hain.
      _c.loadRequest(Uri.parse('https://m.youtube.com/watch?v=$yt'));
    } else if (yt != null) {
      // rel=0: sirf aapke channel ke suggestions, fs=0: YouTube ka fullscreen button nahi
      final html = '''
<html><body style="margin:0;background:#000">
<iframe style="position:fixed;inset:0;width:100%;height:100%;border:0"
 src="https://www.youtube.com/embed/$yt?autoplay=1&rel=0&playsinline=1&fs=0&modestbranding=1&enablejsapi=1&origin=https://com.highschool.assam"
 allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
</body></html>''';
      _c.loadHtmlString(html, baseUrl: 'https://com.highschool.assam');
    } else {
      _c.loadRequest(Uri.parse(videoUrl(widget.url)));
    }
  }

  // Video ko aage/piche karna ya roknaa/chalana (page ke video element par)
  void _seek(int sec) => _c.runJavaScript(
      "var v=document.querySelector('video'); if(v){v.currentTime=Math.max(0,v.currentTime+($sec));}");

  void _toggle() => _c.runJavaScript(
      "var v=document.querySelector('video'); if(v){ if(v.paused){v.play();}else{v.pause();} }");

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _c)),
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () => Navigator.pop(context),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Back',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showSeek)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in [
                      [Icons.replay_10, () => _seek(-10)],
                      [Icons.play_arrow, _toggle],
                      [Icons.forward_10, () => _seek(10)],
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: IconButton(
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black45),
                          icon: Icon(b[0] as IconData, color: Colors.white70),
                          onPressed: b[1] as VoidCallback,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// .txt link: Question = laal (bold), Answer = neela. Poora text apni lambai me.
//
// Txt file me aise likho:
//   Q no-1. বিহুৰ সামাজিক গুৰুত্ব কি?
//   Ans:- বিহু অসমৰ মূল উৎসৱ।
// ya answer alag line me:  উত্তৰঃ ...
// Agle Q tak ki saari lines answer ke rang me aati hain.
// File UTF-8 me save karni hai, warna Assamese/Bengali bigad jati hai.
// ---------------------------------------------------------------------------
class ColoredTxtView extends StatefulWidget {
  final String url;
  const ColoredTxtView({super.key, required this.url});

  @override
  State<ColoredTxtView> createState() => _ColoredTxtViewState();
}

class _ColoredTxtViewState extends State<ColoredTxtView> {
  static const Color _qColor = Color(0xFFD32F2F); // laal
  static const Color _aColor = Color(0xFF1565C0); // neela

  // Question line ki shuruaat: Q no-1, Q1, Q., Question, প্রশ্ন / প্ৰশ্ন
  static final RegExp _qStart = RegExp(
    r'^\s*(Q\s*\.?\s*no|Q\s*\d|Q[.:)]|Question|প্রশ্ন|প্ৰশ্ন)',
    caseSensitive: false,
  );
  // Line ke beech me "Ans:-" ya "Ans:"
  static final RegExp _ansInline =
      RegExp(r'\bAns\s*[:\-]+', caseSensitive: false);
  // Line ki shuruaat me "উত্তৰঃ" / "উত্তরঃ"
  static final RegExp _ansStart = RegExp(r'^\s*(উত্তৰ|উত্তর)\s*[:ঃ\-]');

  late Future<List<TextSpan>> _future = _load();

  Future<List<TextSpan>> _load() async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(widget.url));
      final res = await req.close();
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      return _build(utf8.decode(bytes, allowMalformed: true));
    } finally {
      client.close();
    }
  }

  TextSpan _span(String t, bool answer) => TextSpan(
        text: t,
        style: TextStyle(
          color: answer ? _aColor : _qColor,
          fontWeight: answer ? FontWeight.normal : FontWeight.bold,
        ),
      );

  List<TextSpan> _build(String text) {
    final spans = <TextSpan>[];
    var answerMode = false;
    for (final line in text.split(RegExp(r'\r?\n'))) {
      if (line.trim().isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      final isQuestion = _qStart.hasMatch(line);
      final inline = _ansInline.firstMatch(line);
      if (inline != null) {
        final before = line.substring(0, inline.start);
        if (before.trim().isNotEmpty) {
          spans.add(_span(before, isQuestion ? false : answerMode));
        }
        spans.add(_span(line.substring(inline.start), true));
        answerMode = true;
      } else if (_ansStart.hasMatch(line)) {
        answerMode = true;
        spans.add(_span(line, true));
      } else {
        if (isQuestion) answerMode = false;
        spans.add(_span(line, answerMode));
      }
      spans.add(const TextSpan(text: '\n'));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TextSpan>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          debugPrint('Txt load error: ${snap.error}');
          return Column(
            children: [
              const Text('Text load nahi hua.'),
              TextButton(
                onPressed: () => setState(() => _future = _load()),
                child: const Text('Dobara try karein'),
              ),
            ],
          );
        }
        return SelectableText.rich(
          TextSpan(
            style: const TextStyle(fontSize: 17, height: 1.6),
            children: snap.data,
          ),
        );
      },
    );
  }
}
