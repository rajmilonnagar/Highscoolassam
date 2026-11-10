import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase initialize karein (apni credentials yahan dalein)
  await Supabase.initialize(
    url: 'https://ymiakzzapyhybtoumtbx.supabase.co',
    anonKey: 'sb_publishable_9AC4HbjXewYpiJGOGMPz_A_HKdVimOl',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Highschool Assam',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: const Color(0xFFE91E63), // Magenta / Pink background
      ),
      home: const DeviceCheckScreen(),
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
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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
                const Icon(Icons.lock, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "Your 30-day free trial has expired!",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Please pay ₹10 to continue accessing your studies.",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.pink),
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
        backgroundColor: Colors.pink.shade800,
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
      body: FutureBuilder<List<DbRow>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
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
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
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
                                    color: Colors.pink.shade800)),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: img.isEmpty
                                  ? Container(
                                      color: Colors.pink.shade50,
                                      child: Icon(widget.fallbackIcon,
                                          size: 36, color: Colors.pink))
                                  : CachedNetworkImage(
                                      imageUrl: img,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2)),
                                      errorWidget: (_, __, ___) => Container(
                                          color: Colors.pink.shade50,
                                          child: Icon(widget.fallbackIcon,
                                              size: 36, color: Colors.pink)),
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
                                        fontSize: 18, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                if (sub.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(sub,
                                        style: const TextStyle(color: Colors.grey),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.play_circle_fill,
                              size: 36, color: Colors.pink.shade700),
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
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          color: Colors.pink.shade50,
                          child: img.isEmpty
                              ? Icon(widget.fallbackIcon, size: 50, color: Colors.pink)
                              : CachedNetworkImage(
                                  imageUrl: img,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (_, __, ___) => Icon(widget.fallbackIcon,
                                      size: 50, color: Colors.pink),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          (item['name'] ?? '') as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: Colors.pink),
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
    return ItemGridScreen(
      title: 'Select Medium',
      subtitle: 'ID: $shortId... | Free Trial: $remainingDays Days Left',
      fallbackIcon: Icons.school,
      loader: () async => List<DbRow>.from(
          await _db.from('mediums').select().order('sort_order')),
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
      loader: () async => List<DbRow>.from(
          await _db.from('classes').select().order('sort_order')),
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
    return ItemGridScreen(
      title: '${cls['name']} - Subjects',
      fallbackIcon: Icons.book,
      loader: () async => List<DbRow>.from(await _db
          .from('subjects')
          .select()
          .eq('medium_id', medium['id'])
          .eq('class_id', cls['id'])
          .order('sort_order')),
      onTap: (context, subject) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChapterListScreen(subject: subject)),
      ),
    );
  }
}

class ChapterListScreen extends StatelessWidget {
  final DbRow subject;
  const ChapterListScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    return ItemGridScreen(
      title: '${subject['name']}',
      fallbackIcon: Icons.menu_book,
      listStyle: true,
      loader: () async => List<DbRow>.from(await _db
          .from('chapters')
          .select()
          .eq('subject_id', subject['id'])
          .order('sort_order')),
      onTap: (context, chapter) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ContentScreen(chapter: chapter)),
      ),
    );
  }
}

// Content: Videos / PDF Notes / Q & A

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
      .order('sort_order'));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.chapter['name']}'),
          backgroundColor: Colors.pink.shade800,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.video_library), text: 'Videos'),
              Tab(icon: Icon(Icons.picture_as_pdf), text: 'PDF Notes'),
              Tab(icon: Icon(Icons.question_answer), text: 'Q & A'),
            ],
          ),
        ),
        body: FutureBuilder<List<DbRow>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
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
                  icon: Icons.picture_as_pdf,
                  empty: 'PDF jald aayenge',
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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(empty, style: const TextStyle(color: Colors.white, fontSize: 18)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Icon(icon, color: Colors.pink, size: 36),
            title: Text('${r['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => isVideo
                      ? VideoPlayerScreen(url: open(r))
                      : WebViewScreen(title: '${r['title']}', url: open(r))),
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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
          child: Text('Q & A jald aayenge', style: TextStyle(color: Colors.white, fontSize: 18)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ExpansionTile(
          title: Text('${items[i]['title']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedAlignment: Alignment.centerLeft,
          children: [Text('${items[i]['body'] ?? ''}')],
        ),
      ),
    );
  }
}

// Video aur PDF dono isi me khulte hain

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
        backgroundColor: Colors.pink.shade800,
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
