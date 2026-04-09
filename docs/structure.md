# Struktur Proyek — Panduan Singkat

Tujuan: Standarisasi layout proyek agar mudah dikembangkan, modular, dan mudah ditest.

## Layout Direkomendasikan

- `lib/`
  - `lib/main.dart` — entrypoint aplikasi
  - `lib/src/core/`
    - `data/` — database helpers, repositories (contoh: `database_helper.dart`)
    - `services/` — layanan seperti network clients, intent helpers
    - `widgets/` — komponen UI yang reusable
    - `utils/` — helper, konversi, formatters
    - `models/` — data model / DTO
    - `themes/` — tema, colors, text styles
  - `lib/src/features/` — tiap fitur dalam subfolder
    - `monitoring/` — contoh: `network_page.dart`, `history_page.dart`
    - `<feature>/` — screens, widgets, models, data (per fitur)

- `assets/`
  - `assets/images/`
  - `assets/icons/`
  - `assets/fonts/`

- `test/`
  - `unit/`
  - `widget/`

- `docs/` — panduan arsitektur & migrasi (file ini berada di sini)
- `scripts/` — helper scripts (opsional)

## Aturan & Konvensi Singkat

- Gunakan `package:limit_kuota/src/...` untuk import internal (hindari relative `../`).
- Nama file halaman/komponen: `snake_case` (contoh: `network_page.dart`).
- Folder fitur harus berisi `screens/`, `widgets/`, `models/`, `data/` bila relevan.
- Services / data access diletakkan di `core/` agar dapat dipakai lintas fitur.
- Gunakan `git mv` saat memindahkan file untuk menjaga history.
- Lakukan perubahan bertahap per-PR kecil (maks 10–15 file).

## Contoh Mapping Awal (dari posisi sekarang)

- `lib/network.dart` → `lib/src/features/monitoring/network_page.dart`
- `lib/history_page.dart` → `lib/src/features/monitoring/history_page.dart`
- `lib/db_helper.dart` → `lib/src/core/data/database_helper.dart`
- `lib/helper.dart` → `lib/src/core/services/intent_helper.dart`

## Checklist Migrasi (PR kecil)

1. Buat branch: `git checkout -b refactor/structure/<area>`
2. Buat folder target.
3. `git mv` file ke lokasi baru.
4. Perbarui imports ke `package:limit_kuota/src/...` atau gunakan barrel files.
5. Jalankan `flutter pub get`, `flutter analyze`, `flutter test`.
6. Commit, push, dan buka PR dengan mapping file lama→baru.

---

Dokumentasi ini dibuat untuk mempermudah assign tugas refactor kepada junior programmer atau model AI yang mengotomasi pemindahan file.
