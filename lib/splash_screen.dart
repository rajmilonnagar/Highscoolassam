import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 2 second ka splash video. Video na chale tab bhi 2 second baad aage badh jata hai.
class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _c;
  Timer? _timer;
  bool _ready = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _goNext);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.asset('assets/videos/splash.mp4');
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _ready = true;
      });
      c.play();
    } catch (_) {
      // Video na mile to bhi app chalta rahega
    }
  }

  void _goNext() {
    if (_gone || !mounted) return;
    _gone = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.next),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: (c != null && _ready)
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            : const Center(
                child: Text(
                  'Highschool Assam',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFAD1457),
                  ),
                ),
              ),
      ),
    );
  }
}
