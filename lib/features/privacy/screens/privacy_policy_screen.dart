import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_footer.dart';

/// Full in-app Privacy Policy for MPorT Go.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _bg = Color(0xFF0B0B0F);
  static const _card = Color(0xFF15151C);
  static const _green = Color(0xFF00E5A0);
  static const _muted = Color(0xFF9A9AA6);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? _bg : theme.scaffoldBackgroundColor;
    final card = isDark ? _card : theme.cardColor;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final bodyColor = isDark ? _muted : theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: titleColor,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: titleColor),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(card, titleColor, bodyColor),
              const SizedBox(height: 20),
              _section(
                card,
                titleColor,
                bodyColor,
                '1. Introduction',
                'MPorT Go (“Aplikasi”, “kami”) adalah aplikasi pengujian kecepatan internet '
                'yang dikembangkan untuk mengukur latency (ping), download, dan upload '
                'pada perangkat Anda.\n\n'
                'Kebijakan Privasi ini menjelaskan data apa yang kami proses, untuk tujuan '
                'apa, bagaimana data disimpan, dan hak Anda sebagai pengguna. Dengan '
                'menginstal dan menggunakan MPorT Go, Anda menyetujui praktik yang '
                'dijelaskan di sini.\n\n'
                'Terakhir diperbarui: 25 Agustus 2026\n'
                'Versi aplikasi: ${AppConstants.appVersion}+${AppConstants.appBuild}',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '2. Data yang Kami Proses',
                'MPorT Go dirancang dengan prinsip minimalisasi data. Kami tidak membuat '
                'akun pengguna dan tidak mengharuskan login.\n\n'
                '2.1 Data yang diproses di perangkat (lokal)\n'
                '• Hasil tes kecepatan: ping, jitter, download, upload, packet loss, '
                'waktu tes, dan server yang dipilih.\n'
                '• Preferensi aplikasi: unit kecepatan, skala gauge, mode multi-koneksi, '
                'tema (light/dark/system).\n'
                '• Riwayat tes: disimpan di penyimpanan lokal perangkat (SharedPreferences) '
                'maksimal sekitar 100 entri.\n\n'
                '2.2 Data jaringan teknis (untuk menjalankan tes)\n'
                '• Alamat IP publik Anda dapat terdeteksi oleh server tes saat koneksi '
                'HTTP dilakukan (sifat dasar internet).\n'
                '• Nama jaringan Wi‑Fi (SSID) dapat dibaca di perangkat jika izin lokasi '
                'atau Nearby Wi‑Fi Devices diberikan, semata-mata untuk menampilkan label '
                'koneksi di layar tes. SSID tidak dikirim ke server MPorT untuk pemasaran.\n'
                '• Jenis koneksi (Wi‑Fi / mobile / ethernet) dideteksi lewat API sistem.\n\n'
                '2.3 Data perangkat\n'
                '• Model perangkat (mis. dari device_info) dapat ditampilkan di UI dan '
                'disimpan di riwayat lokal.\n\n'
                '2.4 Data yang TIDAK kami kumpulkan\n'
                '• Kami tidak mengumpulkan nama, email, nomor telepon, atau identitas '
                'pribadi lainnya.\n'
                '• Kami tidak menjual data pengguna.\n'
                '• Kami tidak menampilkan iklan pihak ketiga di dalam alur tes inti.\n'
                '• Kami tidak merekam lokasi GPS presisi untuk pelacakan pergerakan.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '3. Izin yang Diminta',
                '3.1 Internet & status jaringan\n'
                'Diperlukan untuk mengirim/menerima data tes kecepatan ke server uji.\n\n'
                '3.2 Lokasi (saat digunakan) / Nearby Wi‑Fi Devices\n'
                'Di Android, membaca SSID Wi‑Fi memerlukan izin lokasi atau '
                'NEARBY_WIFI_DEVICES (bergantung versi OS). Izin ini hanya dipakai untuk '
                'menampilkan nama jaringan di UI. Anda dapat menolak izin; aplikasi tetap '
                'berfungsi, tetapi label Wi‑Fi mungkin diganti teks generik “Wi‑Fi”.\n\n'
                '3.3 Notifikasi\n'
                'Opsional. Jika diberikan, aplikasi dapat menampilkan notifikasi lokal '
                'saat tes selesai, berisi ringkasan hasil (download, upload, ping). '
                'Notifikasi dibuat di perangkat; tidak memerlukan akun cloud.\n\n'
                '3.4 Wake lock (opsional teknis)\n'
                'Digunakan sementara selama tes agar pengukuran tidak terganggu saat '
                'layar redup pada beberapa perangkat.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '4. Cara Kerja Tes & Pihak Ketiga',
                'Saat Anda menjalankan tes, perangkat mengirim permintaan jaringan ke '
                'server uji yang dikonfigurasi di aplikasi (endpoint download/upload/ping).\n\n'
                'Server uji dan infrastruktur jaringan yang dilalui (ISP, CDN, dll.) '
                'secara teknis dapat melihat metadata koneksi seperti IP, waktu, dan '
                'volume data — sama seperti saat Anda membuka situs web biasa.\n\n'
                'Jika fitur lookup ISP/ASN diaktifkan, aplikasi dapat memanggil layanan '
                'geo-IP/ASN publik untuk menampilkan nama ISP. Respons dapat di-cache '
                'secara lokal di perangkat untuk mengurangi panggilan berulang.\n\n'
                'Kami tidak mengontrol kebijakan privasi server atau layanan pihak ketiga '
                'di luar kendali pengembang. Gunakan jaringan yang Anda percayai.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '5. Penyimpanan & Keamanan',
                '• Riwayat dan preferensi disimpan lokal di perangkat Anda.\n'
                '• Data lokal dapat hilang jika aplikasi di-uninstall atau data aplikasi '
                'dihapus dari pengaturan sistem.\n'
                '• Kami menerapkan praktik wajar pada klien (timeout, penanganan error), '
                'tetapi tidak ada transmisi internet yang 100% bebas risiko.\n'
                '• Disarankan menjaga OS dan aplikasi tetap diperbarui.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '6. Retensi Data',
                '• Riwayat tes disimpan sampai Anda menghapusnya di tab History, atau '
                'menghapus data aplikasi / uninstall.\n'
                '• Jumlah entri dibatasi (sekitar 100) agar penyimpanan tetap ringan.\n'
                '• Cache ISP/ASN lokal bersifat sementara dan dapat diperbarui saat '
                'jaringan berubah.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '7. Hak Anda',
                'Anda dapat:\n'
                '• Menolak atau mencabut izin lokasi dan notifikasi kapan saja melalui '
                'pengaturan sistem perangkat.\n'
                '• Menghapus riwayat tes di dalam aplikasi.\n'
                '• Menghapus seluruh data aplikasi lewat pengaturan Android/iOS.\n'
                '• Berhenti menggunakan aplikasi dengan meng-uninstallnya.\n\n'
                'Karena kami tidak mengoperasikan akun pengguna terpusat, permintaan '
                '“hapus akun cloud” tidak berlaku; kontrol utama ada di perangkat Anda.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '8. Anak-Anak',
                'Aplikasi tidak ditujukan untuk anak di bawah 13 tahun (atau usia minimum '
                'yang berlaku di yurisdiksi Anda). Kami tidak dengan sengaja mengumpulkan '
                'data pribadi dari anak. Jika Anda adalah orang tua/wali dan merasa anak '
                'memberikan data melalui aplikasi, hentikan penggunaan dan hapus data '
                'aplikasi di perangkat.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '9. Perubahan Kebijakan',
                'Kami dapat memperbarui Kebijakan Privasi ini dari waktu ke waktu, misalnya '
                'karena perubahan fitur atau persyaratan hukum. Versi terbaru akan '
                'ditampilkan di halaman ini di dalam aplikasi. Penggunaan berkelanjutan '
                'setelah perubahan berarti Anda memahami kebijakan yang diperbarui.',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '10. Kontak',
                'Untuk pertanyaan terkait privasi MPorT Go, hubungi pengembang melalui '
                'saluran resmi yang tercantum di halaman About di dalam aplikasi, atau '
                'melalui distribusi/store tempat Anda mengunduh aplikasi.\n\n'
                'Pengembang: HaaNSirO / MPorT Go\n'
                'Aplikasi: ${AppConstants.appName}\n'
                'Versi: ${AppConstants.appVersion}+${AppConstants.appBuild}',
              ),
              _section(
                card,
                titleColor,
                bodyColor,
                '11. Ringkasan Singkat',
                '• Tes kecepatan membutuhkan koneksi internet.\n'
                '• Hasil & preferensi disimpan di perangkat Anda.\n'
                '• Izin lokasi hanya untuk menampilkan SSID Wi‑Fi (opsional).\n'
                '• Notifikasi hasil tes bersifat lokal dan opsional.\n'
                '• Kami tidak menjual data pribadi Anda.',
              ),
              const SizedBox(height: 16),
              const AppFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Color card, Color titleColor, Color bodyColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: _green, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kebijakan Privasi MPorT Go',
                  style: TextStyle(
                    color: _green,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Transparansi tentang data, izin, dan cara kerja aplikasi tes kecepatan internet.',
            style: TextStyle(color: bodyColor, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _section(
    Color card,
    Color titleColor,
    Color bodyColor,
    String title,
    String body,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: bodyColor,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
