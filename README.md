# MPorT Tes Speed

Aplikasi Flutter untuk menguji kecepatan internet menggunakan server **HaaNSirO**.

## Server

- Base URL: `https://speed2.haansiro.id`
- Download: `GET /downloading`
- Upload: `POST /upload`

Implementasi mengikuti mekanisme OpenSpeedTest (koneksi paralel 6 thread + overhead adjustment).

## Fitur

- Ping & Jitter
- Download speed (6 parallel threads)
- Upload speed (6 parallel threads, payload 5 MB)
- Gauge speed (tema dark + gold)
- Riwayat hasil lokal (SharedPreferences)
- Navigasi bottom: Tes Speed | Riwayat

## Struktur

```
lib/
├── main.dart
├── app/                    # Router & theme (opsional / ekspansi)
├── core/
│   ├── constants/          # server_config, app_constants
│   ├── network/
│   ├── storage/
│   ├── utils/
│   └── widgets/
└── features/
    ├── speed_test/         # Mesin utama + UI
    │   ├── models/
    │   ├── services/       # ping, download, upload, history
    │   └── screens/        # main, speed_test, history
    ├── history/
    ├── server/
    ├── settings/
    └── about/
```

## Menjalankan

```bash
flutter create . --project-name mport_test_speed --org com.mport
flutter pub get
flutter run
```

## Catatan

- Pengukuran perlu diuji di perangkat nyata.
- Struktur feature-based disiapkan untuk ekspansi (server selection, settings, about).
