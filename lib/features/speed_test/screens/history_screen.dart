import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_footer.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final HistoryService _service = HistoryService();

  List<Map<String, dynamic>> history = [];
  bool loading = true;
  bool _sharing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Called from MainScreen when the History tab is selected.
  Future<void> reload() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final data = await _service.getHistory();
      if (!mounted) return;
      setState(() {
        history = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        history = [];
        loading = false;
      });
    }
  }

  Future<void> _confirmClear() async {
    if (history.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dp = AppPalette.of(ctx);
        return AlertDialog(
          backgroundColor: dp.card,
          title: Text(
            'Clear all history?',
            style: TextStyle(color: dp.textPrimary),
          ),
          content: Text(
            'All saved test results will be permanently deleted.',
            style: TextStyle(color: dp.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await _service.clearHistory();
      if (!mounted) return;
      setState(() => history.clear());
    }
  }

  Future<void> _removeAt(int index) async {
    await _service.removeAt(index);
    if (!mounted) return;
    setState(() {
      if (index >= 0 && index < history.length) {
        history.removeAt(index);
      }
    });
  }

  /// Build CSV and open the system share sheet.
  Future<void> _shareCsv() async {
    if (history.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final csv = await compute(_buildHistoryCsv, history);
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/mport_history_$stamp.csv');
      await file.writeAsString(csv, flush: true);

      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv', name: 'mport_history_$stamp.csv')],
        subject: 'MPorT Go — Speed Test History',
        text: 'Speed test history export (${history.length} results)',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(
          'Test History',
          style: TextStyle(
            color: p.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: p.background,
        automaticallyImplyLeading: false,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Share as CSV',
              onPressed: _sharing ? null : _shareCsv,
              icon: _sharing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.primary,
                      ),
                    )
                  : Icon(Icons.ios_share_rounded, color: p.textPrimary),
            ),
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              onPressed: _confirmClear,
              icon: Icon(Icons.delete_outline, color: p.textPrimary),
            ),
          appMenuButton(context),
        ],
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(color: p.primary),
            )
          : history.isEmpty
              ? const _EmptyHistory()
              : RefreshIndicator(
                  color: p.primary,
                  onRefresh: reload,
                  child: ListView.builder(
                    // KeepAlive + builder: only visible cards paint.
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: history.length + 2, // summary + items + footer
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return RepaintBoundary(
                          child: _SummaryHeader(history: history),
                        );
                      }
                      if (index == history.length + 1) {
                        return const AppFooter(compact: true);
                      }
                      final i = index - 1;
                      final id = history[i]['id']?.toString() ??
                          history[i]['testId']?.toString() ??
                          '$i';
                      return RepaintBoundary(
                        key: ValueKey(id),
                        child: Dismissible(
                          key: ValueKey('dismiss_$id'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) => _removeAt(i),
                          child: _HistoryCard(data: history[i]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Top-level for [compute] — builds CSV off the UI isolate.
String _buildHistoryCsv(List<Map<String, dynamic>> rows) {
  const headers = [
    'timestamp',
    'test_id',
    'download_mbps',
    'upload_mbps',
    'ping_ms',
    'jitter_ms',
    'avg_ping_ms',
    'max_ping_ms',
    'packet_loss_pct',
    'server',
    'server_location',
    'isp',
    'network_name',
    'connection',
    'device_model',
  ];
  final buf = StringBuffer();
  buf.writeln(headers.join(','));
  for (final e in rows) {
    String cell(Object? v) {
      final s = (v ?? '').toString().replaceAll('"', '""');
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"$s"';
      }
      return s;
    }

    buf.writeln([
      cell(e['timestamp']),
      cell(e['testId'] ?? e['id']),
      cell(e['download']),
      cell(e['upload']),
      cell(e['ping']),
      cell(e['jitter']),
      cell(e['avgPing']),
      cell(e['maxPing']),
      cell(e['packetLossPercent']),
      cell(e['server']),
      cell(e['serverLocation']),
      cell(e['isp']),
      cell(e['networkName']),
      cell(e['connectionKind']),
      cell(e['deviceModel']),
    ].join(','));
  }
  return buf.toString();
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 72, color: p.textMuted),
          const SizedBox(height: 16),
          Text(
            'No test history yet',
            style: TextStyle(color: p.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Run a speed test — results will appear here',
            style: TextStyle(color: p.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _SummaryHeader({required this.history});

  double _avg(String key) {
    if (history.isEmpty) return 0;
    var sum = 0.0;
    for (final e in history) {
      sum += _HistoryCard._number(e[key]);
    }
    return sum / history.length;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final avgDl = _avg('download');
    final avgUl = _avg('upload');
    final avgPing = _avg('ping');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _stat(context, 'Tests', '${history.length}', ''),
          _stat(context, 'Avg ↓', avgDl.toStringAsFixed(1), 'Mbps'),
          _stat(context, 'Avg ↑', avgUl.toStringAsFixed(1), 'Mbps'),
          _stat(context, 'Avg Ping', avgPing.toStringAsFixed(0), 'ms'),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, String unit) {
    final p = AppPalette.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: p.textMuted, fontSize: 10)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: p.primaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(color: p.textMuted, fontSize: 9),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HistoryCard({required this.data});

  static double _number(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final download = _number(data['download']);
    final upload = _number(data['upload']);
    final ping = _number(data['ping']);
    final jitter = _number(data['jitter']);
    final avgPing = _number(data['avgPing']);
    final maxPing = _number(data['maxPing']);
    final loss = _number(data['packetLossPercent']);
    final server = (data['server'] ?? '—').toString();
    final location = (data['serverLocation'] ?? '').toString();
    final isp = (data['isp'] ?? '').toString();
    final network = (data['networkName'] ?? '').toString();
    final kind = (data['connectionKind'] ?? '').toString();
    final device = (data['deviceModel'] ?? '').toString();
    final testId = (data['testId'] ?? data['id'] ?? '').toString();

    DateTime? ts;
    try {
      ts = DateTime.tryParse(data['timestamp']?.toString() ?? '');
    } catch (_) {}
    final timeLabel = ts == null
        ? '—'
        : '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} '
            '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

    final networkLabel = network.isNotEmpty
        ? network
        : (isp.isNotEmpty ? isp : (kind.isNotEmpty ? kind : 'Network'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: p.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(_connIcon(kind), size: 14, color: p.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  networkLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.primaryLight, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BigValue(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  value: download,
                  unit: 'Mbps',
                  color: p.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BigValue(
                  icon: Icons.upload_rounded,
                  label: 'Upload',
                  value: upload,
                  unit: 'Mbps',
                  color: const Color(0xFF4DA3FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SmallValue(title: 'Ping', value: ping, unit: 'ms'),
              ),
              Expanded(
                child: _SmallValue(
                  title: 'Avg',
                  value: avgPing > 0 ? avgPing : ping,
                  unit: 'ms',
                ),
              ),
              Expanded(
                child: _SmallValue(title: 'Jitter', value: jitter, unit: 'ms'),
              ),
              Expanded(
                child: _SmallValue(title: 'Loss', value: loss, unit: '%'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.dns_rounded, size: 13, color: p.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location.isNotEmpty ? '$server · $location' : server,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textMuted, fontSize: 11),
                ),
              ),
              if (device.isNotEmpty) ...[
                Icon(Icons.smartphone, size: 13, color: p.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    device,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
          if (testId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'ID: $testId',
              style: TextStyle(
                color: p.textMuted.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _connIcon(String kind) {
    switch (kind.toLowerCase()) {
      case 'wifi':
        return Icons.wifi;
      case 'mobile':
        return Icons.signal_cellular_alt;
      case 'ethernet':
        return Icons.settings_ethernet;
      default:
        return Icons.network_check;
    }
  }
}

class _BigValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _BigValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value.toStringAsFixed(1),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallValue extends StatelessWidget {
  final String title;
  final double value;
  final String unit;

  const _SmallValue({
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      children: [
        Text(title, style: TextStyle(color: p.textMuted, fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(unit == '%' || unit == 'ms' ? 0 : 1),
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(unit, style: TextStyle(color: p.textMuted, fontSize: 8)),
      ],
    );
  }
}
