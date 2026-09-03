import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme_manager.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';

class SettingsScreen extends StatefulWidget {
  final TextEditingController hostController;
  const SettingsScreen({Key? key, required this.hostController}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool autoApprove = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bgOf(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Entrance(
                child: Row(
                  children: [
                    Text('Settings',
                        style: TextStyle(
                          color: AppPalette.textPrimary(context),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        )),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppPalette.green.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppPalette.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, color: AppPalette.green, size: 8),
                          const SizedBox(width: 6),
                          const Text('Connected',
                              style: TextStyle(
                                  color: AppPalette.green, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Entrance(
                delayMs: 100,
                child: _sectionCard(
                  context,
                  icon: Icons.dns_rounded,
                  title: 'Connection',
                  child: Column(
                    children: [
                      TextField(
                        controller: widget.hostController,
                        decoration: const InputDecoration(
                          labelText: 'Backend host',
                          hintText: 'localhost',
                          prefixIcon: Icon(Icons.lan_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          label: 'Save & Test Connection',
                          icon: Icons.check_rounded,
                          height: 46,
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Entrance(
                delayMs: 180,
                child: _sectionCard(
                  context,
                  icon: Icons.link_rounded,
                  title: 'Integrations',
                  child: Column(
                    children: [
                      _integrationRow(
                        icon: Icons.merge_type_rounded,
                        label: 'GitLab Webhook',
                        subtitle: 'Connected',
                        value: true,
                        color: const Color(0xFFFC6D26),
                        onChanged: (v) {},
                      ),
                      const SizedBox(height: 8),
                      _integrationRow(
                        icon: Icons.code_rounded,
                        label: 'GitHub',
                        subtitle: 'Not connected',
                        value: false,
                        color: const Color(0xFF24292F),
                        onChanged: (v) {},
                      ),
                      const SizedBox(height: 8),
                      _integrationRow(
                        icon: Icons.forum_rounded,
                        label: 'Microsoft Teams',
                        subtitle: 'Connected',
                        value: true,
                        color: const Color(0xFF6264A7),
                        onChanged: (v) {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Entrance(
                delayMs: 260,
                child: _sectionCard(
                  context,
                  icon: Icons.tune_rounded,
                  title: 'Preferences',
                  child: Column(
                    children: [
                      _switchRow(
                        context,
                        'Push Notifications',
                        'Get notified of review results',
                        Icons.notifications_rounded,
                        color: AppPalette.primary,
                        value: autoApprove,
                        onChanged: (v) => setState(() => autoApprove = v),
                      ),
                      const SizedBox(height: 4),
                      _switchRow(
                        context,
                        'Dark Mode',
                        'Switch between light and dark themes',
                        Icons.dark_mode_rounded,
                        color: AppPalette.secondary,
                        value: !isLightTheme.value,
                        onChanged: (v) => setState(() => isLightTheme.value = !v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Entrance(
                delayMs: 340,
                child: GlassCard(
                  glow: true,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(gradient: AppPalette.brandGradient, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PRAssist.ai v1.0.0',
                              style: TextStyle(
                                  color: AppPalette.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text('Made for modern engineering teams',
                              style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _sectionCard(BuildContext context,
      {required IconData icon, required String title, required Widget child}) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: AppPalette.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 17, color: AppPalette.primary),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(color: AppPalette.textPrimary(context), fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _integrationRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required Color color,
    required Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppPalette.textPrimary(context), fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 12)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: Colors.white, activeTrackColor: color),
      ],
    );
  }

  Widget _switchRow(BuildContext context, String title, String subtitle, IconData icon,
      {required Color color, required bool value, required Function(bool) onChanged}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: color, size: 19)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: AppPalette.textPrimary(context), fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 11.5)),
                ],
              ),
            ),
            CupertinoSwitch(value: value, onChanged: (v) => onChanged(v), activeTrackColor: color),
          ],
        ),
      ),
    );
  }
}
