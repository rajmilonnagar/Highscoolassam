import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
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
            return _Message
