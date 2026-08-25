import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/app_footer.dart';
import '../services/history_service.dart';

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
        backgroundColor: AppColors.card,
        title: const Text('Hapus semua riwayat?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Semua hasil tes yang tersimpan akan dihapus.',
          style: TextStyle(color: AppColors.textSecondary),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Riwayat Tes',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua',
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_outline, color: AppColors.textPrimary),
            ),
          appMenuButton(context),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            )
          : history.isEmpty
              ? const _EmptyHistory()
              : RefreshIndicator(
                  color: AppColors.green,
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
          Icon(Icons.history_rounded, size: 72, color: AppColors.greenDim),
          SizedBox(height: 16),
          Text(
            'Belum ada riwayat tes',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Jalankan tes speed, hasilnya akan muncul di sini',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _stat('Tes', '${history.length}', ''),
          _stat('Avg ↓', avgDl.toStringAsFixed(1), 'Mbps'),
          _stat('Avg ↑', avgUl.toStringAsFixed(1), 'Mbps'),
          _stat('Avg Ping', avgPing.toStringAsFixed(0), 'ms'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: AppColors.greenLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      color: AppColors.textMuted,
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: time + network
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                _formatDate(timestamp),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(_connIcon(kind), size: 14, color: AppColors.green),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  networkLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.greenLight,
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
                  color: AppColors.greenLight,
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
              const Icon(Icons.dns_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  loc.isNotEmpty ? '$server · $loc' : server,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              if (device.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.smartphone, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    device,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
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
                color: AppColors.textMuted.withValues(alpha: 0.7),
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
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(unit == '%' || unit == 'ms' ? 0 : 1),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(unit,
            style: const TextStyle(color: AppColors.greenDim, fontSize: 8)),
      ],
    );
  }
}
