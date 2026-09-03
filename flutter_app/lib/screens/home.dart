import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  final ValueNotifier<Map<String, dynamic>?> selectedPr;
  final TextEditingController hostController;
  final ValueChanged<Map<String, dynamic>>? onPrTap;
  const HomeScreen({
    Key? key,
    required this.selectedPr,
    required this.hostController,
    this.onPrTap,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> prs = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchPRs();
  }

  Future<void> fetchPRs() async {
    setState(() => loading = true);
    final host = widget.hostController.text.isNotEmpty ? widget.hostController.text : 'localhost';
    try {
      final resp = await http.get(Uri.parse('http://$host:3000/api/prs')).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() => prs = data['prs'] ?? []);
        if (prs.isNotEmpty) widget.selectedPr.value = prs.first;
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

@override
  Widget build(BuildContext context) {
    final recentReviews = prs.length;
    final autoMerged = prs.where((p) => (p['merged'] == true) || (p['state'] == 'merged')).length;
    final accuracy = recentReviews == 0 ? 'N/A' : '${((autoMerged / recentReviews) * 100).round()}%';

    return Scaffold(
      backgroundColor: AppPalette.bgOf(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: fetchPRs,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _header(context),
              const SizedBox(height: 18),
              _hero(context),
              const SizedBox(height: 20),
              _statsRow(recentReviews, autoMerged, accuracy),
              const SizedBox(height: 22),
              SectionLabel(
                title: 'Pull Requests',
                icon: Icons.inbox_rounded,
                trailing: Text(
                  '${prs.length} total',
                  style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              if (loading && prs.isEmpty)
                ...List.generate(3, (_) => const _PrSkeleton())
              else if (prs.isEmpty)
                _EmptyState(onRetry: fetchPRs)
              else
                for (var i = 0; i < prs.length; i++)
                  _PrCard(
                    index: i,
                    pr: prs[i],
                    isNew: i == 0,
                    onTap: () {
                      widget.selectedPr.value = prs[i];
                      if (widget.onPrTap != null) widget.onPrTap!(prs[i] as Map<String, dynamic>);
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Entrance(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRAssist',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  foreground: Paint()
                    ..shader = AppPalette.brandGradient.createShader(
                      const Rect.fromLTWH(0, 0, 150, 40),
                    ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'AI Pull Request Reviewer',
                style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 12.5),
              ),
            ],
          ),
          const Spacer(),
          _IconAction(icon: Icons.notifications_none_rounded, badge: '3', onTap: () {}),
        ],
      ),
    );
  }

Widget _hero(BuildContext context) {
    return Entrance(
      delayMs: 120,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5A4BE0), Color(0xFF8A5CF6), Color(0xFF3BB0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppPalette.primary.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'AI REVIEW ENGINE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Smarter Reviews.\nFaster Merges.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Let Gemini analyze every PR before it ships',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: 'Analyze Latest',
                    icon: Icons.auto_awesome_rounded,
                    height: 46,
                    loading: loading,
                    gradient: const LinearGradient(
                      colors: [Colors.white, Color(0xFFE8ECFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    textStyle: const TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    onPressed: () async => fetchPRs(),
                  ),
                ),
                const SizedBox(width: 10),
                _IconAction(
                  icon: Icons.tune_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(hostController: widget.hostController),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(int reviews, int merged, String accuracy) {
    return Row(
      children: [
        _StatTile(title: 'Reviews', value: reviews, icon: Icons.rate_review_rounded, color: AppPalette.primary, delayMs: 200),
        const SizedBox(width: 10),
        _StatTile(title: 'Merged', value: merged, icon: Icons.merge_rounded, color: AppPalette.green, delayMs: 300),
        const SizedBox(width: 10),
        _StatTile(title: 'Accuracy', valueText: accuracy, icon: Icons.track_changes_rounded, color: AppPalette.secondary, delayMs: 400),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, this.onTap, this.badge});

  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return AnimatedScaleTap(
      onTap: onTap ?? () {},
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppPalette.cardOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.borderOf(context)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppPalette.textPrimary(context), size: 22),
            if (badge != null)
              Positioned(
                top: 7,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppPalette.red,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    this.value = 0,
    this.valueText,
    required this.icon,
    required this.color,
    this.delayMs = 0,
  });

  final String title;
  final int value;
  final String? valueText;
  final IconData icon;
  final Color color;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Entrance(
      delayMs: delayMs,
      duration: const Duration(milliseconds: 550),
      offset: const Offset(0, 16),
      child: Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppPalette.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.borderOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              if (valueText != null)
                Text(valueText!,
                    style: TextStyle(color: AppPalette.textPrimary(context), fontSize: 18, fontWeight: FontWeight.w900))
              else
                AnimatedCounter(
                  value: value,
                  style: TextStyle(color: AppPalette.textPrimary(context), fontSize: 18, fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrCard extends StatelessWidget {
  const _PrCard({required this.index, required this.pr, required this.isNew, required this.onTap});

  final int index;
  final dynamic pr;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = pr['title'] ?? '';
    final number = pr['number']?.toString() ?? '';
    final color = isNew ? AppPalette.green : AppPalette.textSecondary(context).withValues(alpha: 0.7);
    final stateLabel = isNew ? 'NEW' : 'OPEN';

    return Entrance(
      delayMs: 150 + index * 80,
      duration: const Duration(milliseconds: 500),
      offset: const Offset(0, 14),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: AppPalette.brandGradient, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text('#$number',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppPalette.textPrimary(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('by ${pr['author'] ?? 'unknown'}',
                        style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(stateLabel,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: AppPalette.textSecondary(context), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrSkeleton extends StatelessWidget {
  const _PrSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Skeleton(width: 40, height: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: double.infinity, height: 14, radius: 7),
                  SizedBox(height: 8),
                  Skeleton(width: 120, height: 11, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glow: true,
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: AppPalette.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.inbox_rounded, color: AppPalette.primary, size: 26),
          ),
          const SizedBox(height: 12),
          Text('No pull requests yet',
              style: TextStyle(color: AppPalette.textPrimary(context), fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Start the backend and pull to refresh',
              style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 12.5)),
          const SizedBox(height: 14),
          GradientButton(
            label: 'Refresh',
            icon: Icons.refresh_rounded,
            height: 42,
            expanded: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}