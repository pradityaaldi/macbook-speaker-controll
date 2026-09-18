# Speaker Control

Aplikasi menu bar macOS untuk mengatur volume speaker kiri dan kanan secara terpisah,
serta menonaktifkan salah satu sisi speaker (mode mono).

Dibuat untuk MacBook dengan speaker bawaan (diuji pada MacBook Pro, macOS 15.7).

## Fitur

- **Main Volume** — mengatur volume perangkat seperti biasa.
- **Left / Right Volume** — mengatur keseimbangan kiri dan kanan secara terpisah.
- **Left Only / Right Only** — mematikan salah satu sisi speaker dengan satu klik.
  Mono otomatis dinyalakan agar suara dari sisi yang dimatikan tidak hilang.
- **Mono (mix L+R)** — menggabungkan channel kiri dan kanan, sehingga isi kedua
  channel tetap terdengar walau hanya satu speaker yang aktif.
- **Mute** — mute cepat.
- Ikon menu bar menampilkan status: `L` bila hanya kiri aktif, `R` bila hanya kanan aktif.
- Perubahan volume/pan dari tempat lain (tombol volume keyboard, System Settings)
  ikut tersinkron ke tampilan aplikasi.

## Build

Butuh Command Line Tools (tanpa Xcode penuh):

```sh
./build.sh
```

Hasilnya langsung terpasang di `/Applications/Speaker Control.app`.
Skrip ini juga menutup instance yang sedang berjalan dan memperbarui indeks Spotlight,
jadi tidak akan ada duplikat di hasil pencarian.

## Menjalankan

Buka lewat Spotlight (⌘+Space) dengan mengetik `Speaker Control`, atau:

```sh
open -a "Speaker Control"
```

Ikon akan muncul di menu bar. Aplikasi tidak punya ikon Dock (menu bar only).
Untuk keluar, tekan tombol **Quit** di dalam panel.

Agar otomatis jalan saat login: System Settings → General → Login Items → tambahkan
`Speaker Control.app`.

## Cara kerjanya

macOS tidak menyediakan slider kiri/kanan untuk speaker bawaan (System Settings hanya
punya satu volume). Aplikasi ini memakai CoreAudio HAL secara langsung:

| Kebutuhan | API |
|---|---|
| Volume utama | `kAudioDevicePropertyVolumeScalar` (scope output) |
| Keseimbangan kiri/kanan | `kAudioDevicePropertyStereoPan` |
| Mono sejati | `kAudioHardwarePropertyMixStereoToMono` |

**Kenapa perlu `MixStereoToMono`.** Pan pada perangkat bersifat *balance*, bukan
*downmix* — ia meredam channel yang berlawanan, bukan menjumlahkannya. Hal ini sudah
diverifikasi lewat pengukuran akustik: tone yang hanya ada di channel kanan menjadi
hilang total (turun ke level noise floor) ketika pan digeser penuh ke kiri.
Tanpa downmix, menonaktifkan satu speaker berarti kehilangan isi channel tersebut.

`kAudioHardwarePropertyMixStereoToMono` adalah API publik CoreAudio yang sama dengan
setting Accessibility → Audio → "Play stereo audio as mono". Semua diproses di level
driver audio, jadi berlaku untuk seluruh aplikasi tanpa perlu memasang driver tambahan.

**Pemetaan slider.** Perangkat memakai pan law *constant-power*:
`gain kiri = cos(p·π/2)`, `gain kanan = sin(p·π/2)`. Kurva ini diukur dengan memutar
dua tone berbeda frekuensi per channel dan menganalisis rekaman mic internal — hasilnya
cocok dalam ±0.5 dB. Karena itu slider memakai invers eksaknya:

```
p = 2/π · atan2(kanan, kiri)
```

sehingga Kiri 100% / Kanan 50% benar-benar menghasilkan rasio 2:1, dan
Kiri 100% / Kanan 0% menghasilkan pan penuh ke kiri.

## Catatan

- **Mode Mono bersifat sistem-wide.** Ini mengubah output seluruh sistem, sama seperti
  mengubahnya di System Settings. Kalau kamu menyalakannya lewat aplikasi ini, setting
  itu tetap aktif sampai kamu matikan kembali.
- Saat satu sisi disetel ke 0%, aplikasi menampilkan peringatan untuk menyalakan Mono.
  Tombol **Left Only** / **Right Only** menyalakannya otomatis; menggeser slider
  secara manual tidak, supaya tidak mengubah setting sistem tanpa disadari.
- Kontrol kiri/kanan hanya tersedia bila perangkat output mendukung `StereoPan`.
  Sebagian perangkat (mis. beberapa adapter Bluetooth) tidak mendukungnya — slider akan
  otomatis dinonaktifkan dan alasannya ditampilkan di header.
- Aplikasi mengikuti perangkat output default. Saat kamu mencolok headphone, aplikasi
  otomatis beralih ke perangkat tersebut.

## Struktur

```
Sources/
  AudioController.swift   # lapisan CoreAudio: baca/tulis properti, listener, pemetaan pan
  ControlPanel.swift      # tampilan panel menu bar
  SpeakerControlApp.swift # entry point MenuBarExtra
Resources/Info.plist
build.sh
```
