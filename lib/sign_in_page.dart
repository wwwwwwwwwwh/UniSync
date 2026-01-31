import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInPage extends StatefulWidget {
  SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final supabase = Supabase.instance.client;

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool loading = false;
  bool isSignUp = false;

  bool showPass = false;
  bool showConfirm = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => loading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signUp() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    final confirm = confirmCtrl.text;

    if (pass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters.')),
      );
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await supabase.auth.signUp(
        email: email,
        password: pass,
        data: {'full_name': email.split('@').first},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please sign in.')),
      );

      setState(() {
        isSignUp = false;
        confirmCtrl.clear();
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final title = isSignUp ? 'Create your UniSync account' : 'Welcome back';
    final subtitle = isSignUp
        ? 'Set up your student dashboard: timetable, quests, money, and journal.'
        : 'Sign in to continue your campus life dashboard.';

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient + illustration
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary.withValues(alpha: 0.18),
                  cs.secondary.withValues(alpha: 0.14),
                  cs.surface,
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _CampusPainter(
                primary: cs.primary.withValues(alpha: 0.35),
                secondary: cs.secondary.withValues(alpha: 0.25),
              ),
            ),
          ),

          // Floating icons (subtle)
          const Positioned(top: 80, left: 30, child: _FloatIcon(icon: Icons.school_outlined, size: 28)),
          const Positioned(top: 140, right: 38, child: _FloatIcon(icon: Icons.menu_book_outlined, size: 26)),
          const Positioned(bottom: 220, left: 24, child: _FloatIcon(icon: Icons.event_available_outlined, size: 26)),
          const Positioned(bottom: 160, right: 26, child: _FloatIcon(icon: Icons.auto_awesome_outlined, size: 24)),

          // Foreground content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand header
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  cs.primary.withValues(alpha: 0.9),
                                  cs.secondary.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                            child: const Icon(Icons.map_outlined, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('UniSync', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                                SizedBox(height: 2),
                                Text('Campus life, synced.', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(subtitle),
                      ),
                      const SizedBox(height: 14),

                      // Tabs
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Sign In')),
                          ButtonSegment(value: true, label: Text('Create Account')),
                        ],
                        selected: {isSignUp},
                        onSelectionChanged: loading
                            ? null
                            : (s) {
                                setState(() {
                                  isSignUp = s.first;
                                  confirmCtrl.clear();
                                });
                              },
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'name@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: passCtrl,
                        obscureText: !showPass,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: showPass ? 'Hide' : 'Show',
                            onPressed: () => setState(() => showPass = !showPass),
                            icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                          ),
                        ),
                      ),

                      if (isSignUp) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmCtrl,
                          obscureText: !showConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: showConfirm ? 'Hide' : 'Show',
                              onPressed: () => setState(() => showConfirm = !showConfirm),
                              icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: loading ? null : (isSignUp ? _signUp : _signIn),
                          child: Text(
                            loading ? 'Please wait…' : (isSignUp ? 'Create Account' : 'Sign In'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Small “badge row” for first-impression
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _MiniBadge(icon: Icons.schedule_outlined, text: 'Weekly Timetable'),
                          _MiniBadge(icon: Icons.flag_outlined, text: 'Quests'),
                          _MiniBadge(icon: Icons.account_balance_wallet_outlined, text: 'Vault'),
                          _MiniBadge(icon: Icons.edit_note_outlined, text: 'Journal'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        isSignUp ? 'Password tip: 8+ characters.' : 'Welcome back — let’s sync your day.',
                        style: Theme.of(context).textTheme.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------ UI helpers ------------------

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        color: cs.surface.withValues(alpha: 0.80),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            spreadRadius: 2,
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _FloatIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const _FloatIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: 0.35,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: size),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
        color: cs.surface.withValues(alpha: 0.55),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CampusPainter extends CustomPainter {
  final Color primary;
  final Color secondary;

  _CampusPainter({required this.primary, required this.secondary});

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()..color = primary;
    final p2 = Paint()..color = secondary;

    // Soft hills
    final path1 = Path()
      ..moveTo(0, size.height * 0.30)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.24, size.width * 0.50, size.height * 0.30)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.36, size.width, size.height * 0.30)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path1, p1);

    // Campus skyline blocks near bottom
    final baseY = size.height * 0.78;
    final w = size.width;

    void rect(double x, double bw, double bh, Paint paint) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baseY - bh, bw, bh),
          const Radius.circular(10),
        ),
        paint,
      );
    }

    rect(w * 0.08, w * 0.10, size.height * 0.10, p2);
    rect(w * 0.20, w * 0.14, size.height * 0.15, p1);
    rect(w * 0.36, w * 0.12, size.height * 0.12, p2);
    rect(w * 0.52, w * 0.18, size.height * 0.16, p1);
    rect(w * 0.74, w * 0.12, size.height * 0.11, p2);

    // Small “windows” dots
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.25);
    for (int i = 0; i < 20; i++) {
      final dx = (i * 41) % w;
      final dy = baseY - (i % 5) * 18;
      canvas.drawCircle(Offset(dx, dy), 2.4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _CampusPainter oldDelegate) => false;
}
