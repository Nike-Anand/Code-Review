import 'package:flutter/material.dart';
import '../main.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlowStack(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  const _Logo(),
                  const SizedBox(height: 34),

                  Entrance(
                    delayMs: 150,
                    child: Text(
                      'PRAssist',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        foreground: Paint()
                          ..shader = AppPalette.brandGradient.createShader(
                            const Rect.fromLTWH(70, 0, 200, 60),
                          ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Entrance(
                    delayMs: 260,
                    child: Text(
                      'Review pull requests with AI superpowers',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.textSecondary(context),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _Chip(label: 'Fast', icon: Icons.bolt_rounded, delay: 380),
                      SizedBox(width: 10),
                      _Chip(label: 'Accurate', icon: Icons.gpp_good_rounded, delay: 470),
                      SizedBox(width: 10),
                      _Chip(label: 'Always On', icon: Icons.all_inclusive_rounded, delay: 560),
                    ],
                  ),

                  const SizedBox(height: 44),

                  Entrance(
                    delayMs: 620,
                    child: GradientButton(
                      label: 'Get Started',
                      icon: Icons.arrow_forward_rounded,
                      height: 56,
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AppShell()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Entrance(
                    delayMs: 740,
                    child: AnimatedScaleTap(
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AppShell()),
                      ),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(27),
                          border: Border.all(color: AppPalette.primary.withValues(alpha: 0.55), width: 1.4),
                        ),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppPalette.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  Entrance(
                    delayMs: 860,
                    child: Text(
                      'v1.0.0 · Made for modern engineering teams',
                      style: TextStyle(
                        color: AppPalette.textSecondary(context).withValues(alpha: 0.7),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatefulWidget {
  const _Logo({Key? key}) : super(key: key);
  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Entrance(
      duration: const Duration(milliseconds: 800),
      offset: const Offset(0, 10),
      child: SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = 0.82 + 0.18 * _c.value;
                return Container(
                  width: 132 * t,
                  height: 132 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppPalette.primary.withValues(alpha: 0.30),
                        AppPalette.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                );
              },
            ),
            Container(
              width: 106,
              height: 106,
              decoration: BoxDecoration(
                gradient: AppPalette.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.5),
                    blurRadius: 34,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.code_rounded, color: Colors.white, size: 44),
                  Transform.translate(
                    offset: const Offset(22, -22),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF0FA),
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppPalette.primary, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, this.delay = 0});

  final String label;
  final IconData icon;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Entrance(
      delayMs: delay,
      duration: const Duration(milliseconds: 500),
      offset: const Offset(0, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: AppPalette.cardOf(context).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.borderOf(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppPalette.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppPalette.textPrimary(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}