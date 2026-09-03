import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bgOf(context),
      body: SafeArea(
        child: GlowStack(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Entrance(
                  child: Row(
                    children: [
                      Text('Profile',
                          style: TextStyle(
                            color: AppPalette.textPrimary(context),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          )),
                      const Spacer(),
                      const Icon(Icons.more_horiz_rounded, color: Color(0xFF7E8AA0), size: 22),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                Entrance(
                  delayMs: 120,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: AppPalette.heroGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: AppPalette.primary.withValues(alpha: 0.35),
                            blurRadius: 26,
                            offset: const Offset(0, 12)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                          ),
                          child: const Center(
                            child: Text('N',
                                style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text('Nithiyanandam',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('Software Developer',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mail_rounded, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text('nithi@company.com',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Entrance(
                  delayMs: 200,
                  child: Row(
                    children: [
                      _ProfileStat(value: '128', label: 'Reviews', color: AppPalette.primary),
                      const SizedBox(width: 10),
                      _ProfileStat(value: '96%', label: 'Accuracy', color: AppPalette.green),
                      const SizedBox(width: 10),
                      _ProfileStat(value: '57', label: 'Merged', color: AppPalette.secondary),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Entrance(
                  delayMs: 280,
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    child: Column(
                      children: [
                        _menuItem(context, icon: Icons.home_rounded, label: 'Home', color: AppPalette.primary),
                        _menuItem(context, icon: Icons.notifications_rounded, label: 'Notifications', badge: '3', color: AppPalette.red),
                        _menuItem(context, icon: Icons.history_rounded, label: 'History', color: AppPalette.secondary),
                        _menuItem(context, icon: Icons.analytics_rounded, label: 'Analytics', color: AppPalette.primary),
                        _menuItem(context, icon: Icons.settings_rounded, label: 'Settings', color: const Color(0xFF7E8AA0)),
                        _menuItem(context, icon: Icons.info_outline_rounded, label: 'About', color: const Color(0xFF7E8AA0)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _menuItem(BuildContext context,
      {required IconData icon, required String label, Color? color, String? badge}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label tapped'))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? AppPalette.primary).withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color ?? AppPalette.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: AppPalette.textPrimary(context), fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppPalette.red, borderRadius: BorderRadius.circular(12)),
                child: Text(badge,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppPalette.textSecondary(context), size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: AppPalette.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}