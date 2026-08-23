import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
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

  /// Dipanggil dari MainScreen saat tab Riwayat dipilih.
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

  Future<void> clearHistory() async {
    await _service.clearHistory();
    if (!mounted) return;
    setState(() => history.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Test History',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              onPressed: clearHistory,
              icon: const Icon(Icons.delete_outline, color: AppColors.textPrimary),
            ),
          appMenuButton(context),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : history.isEmpty
              ? const _EmptyHistory()
              : RefreshIndicator(
                  color: AppColors.green,
                  onRefresh: reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    itemBuilder: (context, index) =>
                        _HistoryCard(data: history[index]),
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
          Icon(Icons.speed_outlined, size: 70, color: AppColors.greenDim),
          SizedBox(height: 16),
          Text(
            'Belum ada riwayat tes',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'Jalankan tes speed terlebih dahulu',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _HistoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final ping = _number(data['ping']);
    final jitter = _number(data['jitter']);
    final download = _number(data['download']);
    final upload = _number(data['upload']);
    final server = data['server']?.toString() ?? '-';
    final timestamp = DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
        DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                _formatDate(timestamp),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _Value(title: 'PING', value: ping, unit: 'ms')),
              Expanded(
                  child: _Value(title: 'JITTER', value: jitter, unit: 'ms')),
              Expanded(
                  child:
                      _Value(title: 'DOWNLOAD', value: download, unit: 'Mbps')),
              Expanded(
                  child: _Value(title: 'UPLOAD', value: upload, unit: 'Mbps')),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              server,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _Value extends StatelessWidget {
  final String title;
  final double value;
  final String unit;

  const _Value({
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 8),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(color: AppColors.greenDim, fontSize: 7),
        ),
      ],
    );
  }
}
