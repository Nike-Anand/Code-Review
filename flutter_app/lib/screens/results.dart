import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/palette.dart';
import '../widgets/ui.dart';

class ResultsScreen extends StatefulWidget {
  final ValueNotifier<Map<String, dynamic>?> selectedPr;
  final TextEditingController hostController;
  const ResultsScreen({Key? key, required this.selectedPr, required this.hostController}) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Map<String, dynamic>? analysis;
  bool loading = false;
  int selectedTab = 0; // 0=analysis,1=comments,2=files
  List<dynamic> prFiles = [];
  bool loadingFiles = false;

  // Mock/demo analysis used when backend isn't reachable
  final Map<String, dynamic> mockAnalysis = {
    'verdict': 'RED',
    'analysis':
        'VERDICT: RED\nREASON: Could not contact Ollama or Gemini; returning mock analysis.\nISSUES: [Hardcoded API secret found, Missing error handling]\nRECOMMENDATION: Remove API secret and use environment variables.',
    'issues': [
      'CRITICAL: Hardcoded API secret detected in src/authenticate.js',
      'Missing error handling for network failures',
    ],
    'comments': ['Do not commit secrets to the repository!', 'Use environment variables for API_SECRET'],
  };

  @override
  void initState() {
    super.initState();
    widget.selectedPr.addListener(_onPrChanged);
    if (widget.selectedPr.value != null) {
      _runAnalysis(widget.selectedPr.value!);
      fetchPRFiles(widget.selectedPr.value!);
    }
  }

  @override
  void dispose() {
    widget.selectedPr.removeListener(_onPrChanged);
    super.dispose();
  }

  void _onPrChanged() {
    final pr = widget.selectedPr.value;
    if (pr != null) {
      _runAnalysis(pr);
      fetchPRFiles(pr);
    }
  }

  Future<void> fetchPRFiles(Map<String, dynamic> pr) async {
    setState(() {
      loadingFiles = true;
    });
    final host = widget.hostController.text.isNotEmpty ? widget.hostController.text : 'localhost';
    try {
      final resp = await http
          .post(
            Uri.parse('http://$host:3000/api/pr-files'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pr_link': pr['pr_link']}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() => prFiles = body['files'] ?? []);
      } else {
        setState(() => prFiles = []);
      }
    } catch (_) {
      setState(() => prFiles = []);
    }
    if (mounted) setState(() => loadingFiles = false);
  }

  static final Map<String, dynamic> _analysisCache = {};

  Future<void> _runAnalysis(Map<String, dynamic> pr) async {
    final link = pr['pr_link']?.toString() ?? '';
    if (link.isNotEmpty && _analysisCache.containsKey(link)) {
      setState(() {
        analysis = _analysisCache[link];
        loading = false;
      });
      return;
    }

    setState(() {
      loading = true;
      analysis = null;
    });
    final host = widget.hostController.text.isNotEmpty ? widget.hostController.text : 'localhost';
    try {
      final resp = await http
          .post(
            Uri.parse('http://$host:3000/api/analyze-pr'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pr_link': pr['pr_link']}),
          )
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (link.isNotEmpty) _analysisCache[link] = decoded;
        setState(() => analysis = decoded);
      } else {
        setState(() => analysis = mockAnalysis);
      }
    } catch (e) {
      setState(() => analysis = mockAnalysis);
    }
    if (mounted) setState(() => loading = false);
  }

  final List<String> _tabLabels = const ['AI Review', 'Comments', 'Files'];

String _cleanAnalysisText(String raw) {
    var s = raw.toString();
    s = s.replaceAll(RegExp(r'MODEL:\s*\S+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
    return s.trim();
  }

  @override
  Widget build(BuildContext context) {
    final pr = widget.selectedPr.value;
    final verdict = (analysis != null ? (analysis!['verdict'] ?? 'PENDING') : 'PENDING').toString().toUpperCase();

    return Scaffold(
      backgroundColor: AppPalette.bgOf(context),
      body: SafeArea(
        child: pr == null
            ? const _NoPrSelected()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Text('PR Results',
                            style: TextStyle(
                              color: AppPalette.textPrimary(context),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            )),
                        const Spacer(),
                        if (pr['number'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('#${pr['number']}',
                                style: const TextStyle(color: AppPalette.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: loading
                        ? const _AnalysisLoading()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _verdictHero(pr, verdict),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _countChip(
                                      icon: Icons.add_rounded,
                                      count: _getTotalAdditions(pr),
                                      label: 'Added',
                                      color: AppPalette.green,
                                    ),
                                    const SizedBox(width: 10),
                                    _countChip(
                                      icon: Icons.remove_rounded,
                                      count: _getTotalDeletions(pr),
                                      label: 'Removed',
                                      color: AppPalette.red,
                                    ),
                                    const SizedBox(width: 10),
                                    _countChip(
                                      icon: Icons.description_rounded,
                                      count: _fileCount(),
                                      label: 'Files',
                                      color: AppPalette.secondary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                PillTabs(labels: _tabLabels, index: selectedTab, onChanged: _onTabChanged),
                                const SizedBox(height: 16),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: _tabContent(verdict),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                  ),

                  // Action bar
                  _bottomActions(verdict),
                ],
              ),
      ),
    );
  }

  int _fileCount() {
    final c = analysis?['files_changed_count'];
    if (c is int && c > 0) return c;
    final list = analysis?['files_changed'];
    if (list is List) return list.length;
    return prFiles.length;
  }

  int _getTotalAdditions(dynamic pr) {
    if (analysis?['additions'] != null) return (analysis!['additions'] as num).toInt();
    if (pr != null && pr['additions'] != null) return (pr['additions'] as num).toInt();
    int total = 0;
    for (final f in prFiles) {
      total += (f['additions'] as num? ?? 0).toInt();
    }
    return total;
  }

  int _getTotalDeletions(dynamic pr) {
    if (analysis?['deletions'] != null) return (analysis!['deletions'] as num).toInt();
    if (pr != null && pr['deletions'] != null) return (pr['deletions'] as num).toInt();
    int total = 0;
    for (final f in prFiles) {
      total += (f['deletions'] as num? ?? 0).toInt();
    }
    return total;
  }

  void _onTabChanged(int i) {
    setState(() => selectedTab = i);
    if (i == 2 && prFiles.isEmpty && widget.selectedPr.value != null) {
      fetchPRFiles(widget.selectedPr.value!);
    }
  }

Widget _verdictHero(Map<String, dynamic> pr, String verdict) {
    final color = AppPalette.verdictColor(verdict);
    return Entrance(
      duration: const Duration(milliseconds: 550),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppPalette.glowGradient(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 26, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (pr['title'] ?? 'Untitled PR').toString().replaceFirst(RegExp(r'^(RED|YELLOW|GREEN):\s*', caseSensitive: false), ''),
                        style: TextStyle(
                          color: AppPalette.textPrimary(context),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.account_circle_rounded, size: 14, color: AppPalette.textSecondary(context)),
                          const SizedBox(width: 5),
                          Text(
                            'by ${pr['author'] ?? 'unknown'}',
                            style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                VerdictBadge(verdict: verdict),
              ],
            ),
            const SizedBox(height: 16),
            if (analysis != null && ((analysis!['analysis'] ?? '') as String).isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.cardOf(context).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppPalette.borderOf(context)),
                ),
                child: MarkdownBody(
                  data: _cleanAnalysisText(analysis!['analysis'] ?? ''),
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: TextStyle(color: AppPalette.textSecondary(context), fontSize: 13.5, height: 1.45),
                    strong: TextStyle(color: AppPalette.textPrimary(context), fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _countChip({required IconData icon, required int count, required String label, required Color color}) {
    return Expanded(
      child: Entrance(
        duration: const Duration(milliseconds: 500),
        child: GlassCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(height: 8),
              AnimatedCounter(value: count, style: TextStyle(color: AppPalette.textPrimary(context), fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

Widget _tabContent(String verdict) {
    switch (selectedTab) {
      case 0:
        return _ReviewTab(analysis: analysis);
      case 1:
        return _CommentsTab(analysis: analysis);
      case 2:
        return _FilesTab(
          files: prFiles,
          loading: loadingFiles,
          onRefresh: () {
            final pr = widget.selectedPr.value;
            if (pr != null) fetchPRFiles(pr);
          },
        );
      default:
        return const SizedBox();
    }
  }

  Widget _bottomActions(String verdict) {
    final isGreen = verdict == 'GREEN';
    final isRed = verdict == 'RED';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppPalette.bgOf(context),
        border: Border(top: BorderSide(color: AppPalette.borderOf(context))),
      ),
      child: Row(
        children: [
          if (isGreen || (!isRed))
            Expanded(
              child: GradientButton(
                label: 'Approve & Merge',
                icon: Icons.check_rounded,
                height: 48,
                loading: _actionLoading,
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                onPressed: loading ? null : _approvePr,
              ),
            ),
          if (isGreen || (!isRed)) const SizedBox(width: 10),
          if (isRed)
            Expanded(
              child: GradientButton(
                label: 'Request Changes',
                icon: Icons.block_rounded,
                height: 48,
                loading: _actionLoading,
                gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFE11D48)]),
                onPressed: loading ? null : _requestChanges,
              ),
            )
          else
            Expanded(
              child: AnimatedScaleTap(
                onTap: loading ? null : _requestChanges,
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppPalette.primary.withValues(alpha: 0.55), width: 1.4),
                  ),
                  child: Text('Request Changes',
                      style: TextStyle(color: AppPalette.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _actionLoading = false;

  Future<void> _approvePr() async {
    final pr = widget.selectedPr.value;
    if (pr == null) return _showMsg('No PR selected');
    setState(() => _actionLoading = true);
    final host = widget.hostController.text.isNotEmpty ? widget.hostController.text : 'localhost';
    try {
      final resp = await http
          .post(
            Uri.parse('http://$host:3000/api/approve-pr'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pr_link': pr['pr_link']}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _showMsg('Approved ✓');
      } else {
        _showMsg('Approve failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('approvePr error: $e');
      _showMsg('Error contacting backend');
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _requestChanges() async {
    final pr = widget.selectedPr.value;
    if (pr == null) return _showMsg('No PR selected');
    setState(() => _actionLoading = true);
    final host = widget.hostController.text.isNotEmpty ? widget.hostController.text : 'localhost';
    try {
      final resp = await http
          .post(
            Uri.parse('http://$host:3000/api/request-changes'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pr_link': pr['pr_link'], 'comment': 'Please address the issues highlighted by PRAssist.'}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _showMsg('Changes requested');
      } else {
        _showMsg('Request failed: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('requestChanges error: $e');
      _showMsg('Error contacting backend');
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ReviewTab extends StatelessWidget {
  const _ReviewTab({this.analysis});

  final Map<String, dynamic>? analysis;

  @override
  Widget build(BuildContext context) {
    final issues = (analysis?['issues'] is List) ? (analysis!['issues'] as List) : <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (issues.isNotEmpty) ...[
          const SectionLabel(title: 'Key Issues', icon: Icons.report_problem_rounded),
          const SizedBox(height: 10),
          for (final it in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppPalette.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.error_outline_rounded, color: AppPalette.red, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        it.toString(),
                        style: TextStyle(color: AppPalette.textPrimary(context), fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ] else
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppPalette.green, size: 20),
                const SizedBox(width: 10),
                Text('No issues reported', style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}

class _CommentsTab extends StatelessWidget {
  const _CommentsTab({this.analysis});

  final Map<String, dynamic>? analysis;

  @override
  Widget build(BuildContext context) {
    final comments = (analysis?['comments'] is List) ? (analysis!['comments'] as List) : <dynamic>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comments.isNotEmpty)
          for (final c in comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded, color: AppPalette.primary, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.toString(),
                        style: TextStyle(color: AppPalette.textPrimary(context), fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            )
        else
          GlassCard(
            child: Text('No comments yet', style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 13)),
          ),
      ],
    );
  }
}

class _FilesTab extends StatefulWidget {
  const _FilesTab({required this.files, required this.loading, required this.onRefresh});

  final List<dynamic> files;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  State<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<_FilesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.files.where((f) {
      if (_query.isEmpty) return true;
      final name = (f['filename'] ?? '').toString().toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search files...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScaleTap(
              onTap: widget.onRefresh,
              child: Container(
                width: 44,
                height: 48,
                decoration: BoxDecoration(
                  color: AppPalette.cardOf(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.borderOf(context)),
                ),
                child: const Icon(Icons.refresh_rounded, color: AppPalette.primary, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.loading)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (visible.isEmpty)
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.folder_off_rounded, color: Color(0xFF7E8AA0), size: 20),
                const SizedBox(width: 10),
                Text('No files available', style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 13)),
              ],
            ),
          )
        else
          for (final f in visible) _FileTile(file: f),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file});

  final dynamic file;

  @override
  Widget build(BuildContext context) {
    final filename = file['filename'] ?? 'file';
    final adds = (file['additions'] ?? 0) as int;
    final dels = (file['deletions'] ?? 0) as int;
    final status = (file['status'] ?? file['label'] ?? (adds > 0 && dels == 0 ? 'Added' : 'Modified')).toString();
    final patch = file['patch'] ?? file['diff'] ?? null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: AppPalette.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.description_rounded, color: AppPalette.primary, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppPalette.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statPill('+$adds', AppPalette.green),
                const SizedBox(width: 8),
                _statPill('-$dels', AppPalette.red),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: AppPalette.secondary.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
                  child: Text(status,
                      style: const TextStyle(color: AppPalette.secondary, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            if (patch != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppPalette.cardAltOf(context), borderRadius: BorderRadius.circular(12)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    patch.toString(),
                    style: TextStyle(color: AppPalette.textSecondary(context), fontFamily: 'monospace', fontSize: 11.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _AnalysisLoading extends StatelessWidget {
  const _AnalysisLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 18),
          Text('Analyzing with Gemini…',
              style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('This usually takes a few seconds',
              style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 12)),
        ],
      ),
    );
  }
}

class _NoPrSelected extends StatelessWidget {
  const _NoPrSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppPalette.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.rule_rounded, color: AppPalette.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text('No PR selected',
              style: TextStyle(color: AppPalette.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Pick a pull request from the Home feed',
              style: TextStyle(color: AppPalette.textSecondary(context), fontSize: 13)),
        ],
      ),
    );
  }
}
