MPorT Tes Speed

Aplikasi Flutter untuk menguji kecepatan internet menggunakan server pengujian yang dikonfigurasi oleh aplikasi.

Fitur

- Ping & Jitter
- Download speed dengan 6 parallel threads
- Upload speed dengan 6 parallel threads
- Payload upload 4 MB
- Gauge kecepatan dengan tema dark + gold
- Riwayat hasil pengujian secara lokal menggunakan SharedPreferences
- Navigasi bottom:
  - Tes Speed
  - Riwayat

Mesin Speed Test

Aplikasi menggunakan mesin pengujian untuk melakukan:

- Pengujian latency
- Pengukuran jitter
- Pengujian download
- Pengujian upload
- Koneksi paralel untuk meningkatkan akurasi pengukuran
- Penyesuaian overhead pada hasil pengukuran

Detail endpoint, alamat server, dan konfigurasi infrastruktur tidak dipublikasikan dalam dokumentasi proyek.

Menjalankan

flutter create . --project-name mport_test_speed --org com.mport
flutter pub get
flutter run

Konfigurasi Server

Konfigurasi server pengujian dikelola secara internal oleh aplikasi dan tidak ditampilkan pada dokumentasi publik.

Jangan memasukkan alamat server internal, credential, API key, token, atau konfigurasi rahasia ke dalam README atau repository publik.

Catatan

- Pengukuran sebaiknya diuji pada perangkat nyata.
- Hasil speed test dapat dipengaruhi oleh kondisi jaringan, perangkat, lokasi server, dan trafik.
- Struktur aplikasi dirancang agar dapat dikembangkan lebih lanjut dengan fitur tambahan seperti server selection, settings, about, dan network diagnostics.
