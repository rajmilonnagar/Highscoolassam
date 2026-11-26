
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
    url: 'PASTE_SUPABASE_URL_HERE',
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
          backgroundColor: App
