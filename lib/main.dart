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
// App ke rang: gulabi sirf header, button aur active cheezon me
const Color kBrand = Color(0xFFAD1457);
const Color kBg = Color(0xFFF8F9FA);
const Color kGrey = Color(0xFF6B7280);
const Color kThumbBg = Color(0xFFF1F3F5);

/// Safed card: halki parchhai, 16 round kone
Card appCard({required Widget child, EdgeInsetsGeometry? margin}) => Card(
      color: Colors.white,
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
    anonKey: 'sb_publishable_9AC4HbjXewYpiJGOGMPz_A_HKdVimOl',
  );
  runApp(const MyApp());
}

ThemeData _buildTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: kBrand),
    scaffoldBackgroundColor: kBg,
    useMaterial3: true,
  );
  return base.copyWith(textTheme: GoogleFonts.poppinsTextTheme(base.textTheme));
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
        body: Center(child: CircularProgressIndicator(color: kBrand)),
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
                const Icon(Icons.lock, size: 80, color: kBrand),
                const SizedBox(height: 20),
                const Text(
                  "Your 30-day free trial has expired!",
                  style: TextStyle(color: Color(0xFF1F2937), fontSize: 20, fontWeight: FontWeight.bold),
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
                  style: ElevatedButton.styleFrom(backgroundColor: kBrand, foregroundColor: Colors.white),
                  onPressed: () {
                    // Yahan payment gateway trigger hoga
                  },
                  child: const Text("Pay ₹10 Now", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Access granted -> Medium Selection Screen
    return MediumSelectionScreen(deviceId: deviceId, remainingDays: remainingDays);
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
  if (!url.startsWith('http')) url = 'https://iframe.mediadelivery.net/embed/$url';
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
// Generic grid screen: naam + photo wali kisi bhi list ke liye
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: kBrand,
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
            return const Center(child: CircularProgressIndicator(color: kBrand));
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
          if (widget.listStyle) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final img = imageUrl(item['image_url'] as String?);
                final sub = (item['subtitle'] ?? '').toString();
                return appCard(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => widget.onTap(context, item),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: kBrand)),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: img.isEmpty
                                  ? Container(
                                      color: kThumbBg,
                                      child: Icon(widget.fallbackIcon,
                                          size: 36, color: kBrand))
                                  : CachedNetworkImage(
                                      imageUrl: img,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2)),
                                      errorWidget: (_, __, ___) => Container(
                                          color: kThumbBg,
                                          child: Icon(widget.fallbackIcon,
                                              size: 36, color: kBrand)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['name'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1F2937)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                if (sub.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(sub,
                                        style: const TextStyle(color: kGrey, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: widget.aspect,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final img = imageUrl(item['image_url'] as String?);
              return GestureDetector(
                onTap: () => widget.onTap(context, item),
                child: appCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          color: kThumbBg,
                          child: img.isEmpty
                              ? Icon(widget.fallbackIcon, size: 50, color: kBrand)
                              : CachedNetworkImage(
                                  imageUrl: img,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (_, __, ___) => Icon(widget.fallbackIcon,
                                      size: 50, color: kBrand),
                                ),
                        ),
                      ),
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
            },
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
                backgroundColor: kBrand, foregroundColor: Colors.white),
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
  const MediumSelectionScreen({super.key, required this.deviceId, required this.remainingDays});

  @override
  Widget build(BuildContext context) {
    final shortId = deviceId.length > 6 ? deviceId.substring(0, 6) : deviceId;
    return ColorRowsScreen(
      title: 'Select Medium',
      subtitle: 'ID: $shortId... | Free Trial: $remainingDays Days Left',
      fallbackIcon: Icons.school,
      badge: 'symbol',
      showBanner: true,
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
    return ColorRowsScreen(
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

// Content: Videos / MCQ / Book

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
          backgroundColor: kBrand,
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
              return const Center(child: CircularProgressIndicator(color: kBrand));
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
      child: Center(child: Icon(icon, color: kBrand, size: iconSize)),
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
      return Center(child: Text(empty, style: const TextStyle(color: kGrey, fontSize: 18)));
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
              fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
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
                                    color: Colors.black45, shape: BoxShape.circle),
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
                          child: SizedBox(width: 72, height: 72, child: _img(r, 34)),
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

  // Ek square safed card me photo (poori dikhe, kate nahi)
  Widget _pic(String? raw, {double ratio = 1}) {
    final img = imageUrl(raw);
    return appCard(
      child: AspectRatio(
        aspectRatio: ratio,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: img.isEmpty
              ? const Center(child: Icon(Icons.image_outlined, size: 48, color: kThumbBg))
              : Cached
