import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_category_screens.dart';
import 'admin_notice_screen.dart';

const supabaseUrl = 'https://ymiakzzapyhybtoumtbx.supabase.co';
const supabaseKey = 'sb_publishable_9AC4HbjXewYpiJGOGMPz_A_HKdVimOl';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const AdminApp());
}

final db = Supabase.instance.client;
typedef DbRow = Map<String, dynamic>;

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assam Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: db.auth.onAuthStateChange,
      builder: (context, snap) {
        if (db.auth.currentSession == null) return const LoginScreen();
        return mediumsScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await db.auth.signInWithPassword(
          email: _email.text.trim(), password: _pass.text);
    } catch (e) {
      setState(() => _error = 'Login nahi hua. Email/password check karein.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, size: 72, color: Colors.indigo),
              const SizedBox(height: 8),
              const Text('Assam Admin',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password', border: OutlineInputBorder()),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _login,
                  child: Text(_busy ? 'Ruko...' : 'Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screens: Medium -> Class -> Subject -> Chapter -> Content
// ---------------------------------------------------------------------------

const _nameImgOrder = [
  F('name', 'Naam'),
  F('image_url', 'Photo link (Google Drive)'),
  F('sort_order', 'Order (1,2,3...)', number: true),
];

Widget mediumsScreen() => Table
