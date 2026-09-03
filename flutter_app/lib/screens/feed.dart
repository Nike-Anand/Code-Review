import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../theme/palette.dart';
import '../widgets/ui.dart';

class FeedScreen extends StatefulWidget {
  final void Function(Map<String, dynamic>)? onPrTap;
  final TextEditingController? hostController;
  const FeedScreen({Key? key, this.hostController, this.onPrTap}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> items = [];
  Timer? _pollTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchActivity();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => fetchActivity());
  }

  Future<void> fetchActivity() async {
    final host = widget.hostController?.text ?? 'localhost';
    try {
      final resp = await http.get(Uri.parse('http://$host:3000/api/activity')).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['activity'] as List<dynamic>?) ?? [];
        setState(() {
          items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() {
        items = [
          {
            'title': 'Local backend unreachable',
            'subtitle': 'Start backend to see live activity',
            'pr_link': '',
            'type': 'offline',
          }
        ];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bgOf(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Entrance(
                child: Row(
                  children: [
                    Text('Activity Feed',
                        style: TextStyle(
                          color: AppPalette.textPrimary(context),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        )),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${items.length} events',
                          style: const TextStyle(color: AppPalette.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchActivity,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? Center(child: Text('No activity yet', style: TextStyle(color: AppPalette.textSecondary(context))))
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: items.length,
                              itemBuilder: (context, i) => _FeedCard(
                                index: i,
                                item: items[i],
                                onTap: () {
                                  final prLink = (items[i]['pr_link'] ?? '') as String;
                                  if (prLink.isNotEmpty) {
                                    widget.onPrTap?.call({
                                      'pr_link': prLink,
                                      'title': items[i]['title'] ?? 'Activity',
                                      'author': items[i]['actor'] ?? 'system',
                                    });
                                  } else {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(content: Text('Feed item tapped')));
                                  }
                                },
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.index, required this.item, required this.onTap});

  final int index;
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  IconData get _icon {
    final type = (item['type'] ?? '').toString().toLowerCase();
    if (type.contains('approve') || type.contains('green')) return Icons.check_circle_rounded;
    if (type.contains('merge')) return Icons.merge_type_rounded;
    if (type.contains('red')) return Icons.cancel_rounded;
    if (type.contains('yellow')) return Icons.warning_amber_rounded;
    if (type.contains('offline')) return Icons.cloud_off_rounded;
    return Icons.rss_feed_rounded;
  }

  Color get _color {
    final type = (item['type'] ?? '').toString().toLowerCase();
    if (type.contains('approve') || type.contains('green')) return AppPalette.green;
    if (type.contains('merge')) return AppPalette.secondary;
    if (type.contains('red')) return AppPalette.red;
    if (type.contains('yellow')) return AppPalette.yellow;
    if (type.contains('offline')) return const Color(0xFF7E8AA0);
    return AppPalette.primary;
  }

  @override
  Widget build(BuildContext context) {
    final rawTitle = item['title'] ?? (item['message'] ?? 'Activity');
    final title = rawTitle.toString().replaceFirst(RegExp(r'^(RED|YELLOW|GREEN):\s*', caseSensitive: false), '');
    final subtitle = item['message'] ?? item['subtitle'] ?? '';
    final color = _color;

    return Entrance(
      delayMs: 100 + index * 70,
      duration: const Duration(milliseconds: 500),
      offset: const Offset(0, 14),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(_icon, color: color, size: 20),
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
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: AppPalette.textSecondary(context), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}