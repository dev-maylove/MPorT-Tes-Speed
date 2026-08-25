import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_footer.dart';
import '../services/history_service.dart';

Color _bg(BuildContext c) => AppPalette.of(c).background;
Color _card(BuildContext c) => AppPalette.of(c).card;
Color _text(BuildContext c) => AppPalette.of(c).textPrimary;
Color _muted(BuildContext c) => AppPalette.of(c).textMuted;
Color _sec(BuildContext c) => AppPalette.of(c).textSecondary;
Color _prim(BuildContext c) => AppPalette.of(c).primary;
Color _primL(BuildContext c) => AppPalette.of(c).primaryLight;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _service = HistoryService();

  List<Map<String, dynamic>> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Called from MainScreen when the History tab is selected.
  Future<void> reload() async {
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
      builder: (ctx) => AlertDialog(
        backgroundColor: _card(ctx),
        title: Text('Hapus semua riwayat?',
            style: TextStyle(color: _text(ctx))),
        content: Text(
          'Semua hasil tes yang tersimpan akan dihapus.',
          style: TextStyle(color: _sec(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        title: const Text(
          'Riwayat Tes',
          style: TextStyle(
            color: _text(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _bg(context),
        automaticallyImplyLeading: false,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua',
              onPressed: _confirmClear,
              icon: Icon(Icons.delete_outline, color: _text(context)),
            ),
          appMenuButton(context),
        ],
      ),
      body: loading
          ? Center(
              child: CircularProgressIndicator(color: _prim(context)),
            )
          : history.isEmpty
              ? const _EmptyHistory()
              : RefreshIndicator(
                  color: _prim(context),
                  onRefresh: reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: history.length + 2, // summary + items + footer
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _SummaryHeader(history: history);
                      }
                      if (index == history.length + 1) {
                        return const AppFooter();
                      }
                      final i = index - 1;
                      return Dismissible(
                        key: ValueKey(
                          history[i]['id']?.toString() ??
                              history[i]['timestamp']?.toString() ??
                              '$i',
                        ),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                        ),
                        onDismissed: (_) => _removeAt(i),
                        child: _HistoryCard(data: history[i]),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 72, color: _prim(context)Dim),
          SizedBox(height: 16),
          Text(
            'Belum ada riwayat tes',
            style: TextStyle(color: _sec(context), fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Jalankan tes speed, hasilnya akan muncul di sini',
            style: TextStyle(color: _muted(context), fontSize: 12),
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
    final avgDl = _avg('download');
    final avgUl = _avg('upload');
    final avgPing = _avg('ping');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _prim(context).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _stat(context, 'Tes', '${history.length}', ''),
          _stat(context, 'Avg ↓', avgDl.toStringAsFixed(1), 'Mbps'),
          _stat(context, 'Avg ↑', avgUl.toStringAsFixed(1), 'Mbps'),
          _stat(context, 'Avg Ping', avgPing.toStringAsFixed(0), 'ms'),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(color: _muted(context), fontSize: 10)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: _primL(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: _muted(context),
                      fontSize: 9,
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

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _HistoryCard({required this.data});

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  IconData _connIcon(String kind) {
    switch (kind) {
      case 'wifi':
        return Icons.wifi_rounded;
      case 'mobile':
        return Icons.signal_cellular_alt_rounded;
      case 'ethernet':
        return Icons.settings_ethernet_rounded;
      default:
        return Icons.lan_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ping = _number(data['ping']);
    final jitter = _number(data['jitter']);
    final avgPing = _number(data['avgPing']);
    final maxPing = _number(data['maxPing']);
    final loss = _number(data['packetLossPercent']);
    final download = _number(data['download']);
    final upload = _number(data['upload']);
    final server = data['server']?.toString() ?? '-';
    final loc = data['serverLocation']?.toString() ?? '';
    final isp = data['isp']?.toString() ?? '';
    final network = data['networkName']?.toString() ?? '';
    final kind = data['connectionKind']?.toString() ?? '';
    final device = data['deviceModel']?.toString() ?? '';
    final testId = data['testId']?.toString() ?? data['id']?.toString() ?? '';
    final timestamp =
        DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now();

    final networkLabel = network.isNotEmpty
        ? network
        : (isp.isNotEmpty ? isp : (kind.isNotEmpty ? kind : 'Network'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: time + network
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: _muted(context)),
              const SizedBox(width: 6),
              Text(
                _formatDate(timestamp),
                style: const TextStyle(
                  color: _text(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(_connIcon(kind), size: 14, color: _prim(context)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  networkLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primL(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Download / Upload big
          Row(
            children: [
              Expanded(
                child: _BigValue(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  value: download,
                  unit: 'Mbps',
                  color: _primL(context),
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
          // Latency row
          Row(
            children: [
              Expanded(child: _SmallValue(title: 'Ping', value: ping, unit: 'ms')),
              Expanded(child: _SmallValue(title: 'Avg', value: avgPing > 0 ? avgPing : ping, unit: 'ms')),
              Expanded(child: _SmallValue(title: 'Jitter', value: jitter, unit: 'ms')),
              Expanded(child: _SmallValue(title: 'Loss', value: loss, unit: '%')),
              if (maxPing > 0)
                Expanded(child: _SmallValue(title: 'Max', value: maxPing, unit: 'ms')),
            ],
          ),
          const SizedBox(height: 10),
          // Server / device footer
          Row(
            children: [
              Icon(Icons.dns_rounded, size: 13, color: _muted(context)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  loc.isNotEmpty ? '$server · $loc' : server,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted(context),
                    fontSize: 11,
                  ),
                ),
              ),
              if (device.isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(Icons.smartphone, size: 13, color: _muted(context)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    device,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted(context),
                      fontSize: 11,
                    ),
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
                color: _muted(context).withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
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
              Text(label,
                  style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 11)),
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
    return Column(
      children: [
        Text(title,
            style: TextStyle(color: _muted(context), fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(unit == '%' || unit == 'ms' ? 0 : 1),
          style: const TextStyle(
            color: _text(context),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(unit,
            style: TextStyle(color: _prim(context)Dim, fontSize: 8)),
      ],
    );
  }
}
