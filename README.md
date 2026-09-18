# MacBook Speaker Control

Menu-bar app for macOS that controls the left and right speakers of your MacBook
independently, and can disable either side — with a true mono downmix so nothing
is lost.

Built and tested on a MacBook Pro running macOS 15.7.

<img src="Resources/AppIcon.png" width="96" alt="App icon">

## Demo

<video src="https://github.com/user-attachments/assets/7c9d0fa7-6f87-4cb1-b876-75ab6172f43a" controls width="720"></video>

## Features

- **Left / Right volume** — trim each channel separately.
- **Left Only / Right Only** — disable one speaker with a single click.
  Mono is switched on automatically so the disabled side stays audible.
- **Mono (mix L+R)** — sums both channels, so either speaker can play everything.
- **Main volume** and **Mute** without leaving the menu bar.
- Menu-bar icon shows the current state (`L` when only the left side is active,
  `R` when only the right side is active).
- Stays in sync with changes made elsewhere (keyboard volume keys, System Settings).

## Download

Each [release](https://github.com/pradityaaldi/macbook-speaker-controll/releases/latest)
carries a prebuilt app bundle:

1. Download the `SpeakerControl-<version>.zip` and unzip it.
2. Move `Speaker Control.app` to `/Applications`.
3. Launch it — the first time, **right-click → Open**, since the bundle is
   ad-hoc signed rather than notarized.

The published build is `x86_64`; on Apple Silicon it runs under Rosetta 2.
Build from source below for a native binary.

## Build

Requires the Xcode Command Line Tools (no full Xcode install needed):

```bash
./build.sh
```

The script builds the bundle straight into `/Applications/Speaker Control.app`,
quits any running copy first, and refreshes the Spotlight index — so there is
never a stale duplicate in search results.

## Run

Open it from Spotlight (⌘+Space, type `Speaker Control`), or:

```bash
open -a "Speaker Control"
```

The icon appears in the menu bar. There is no Dock icon. To exit, press **Quit**
inside the panel.

To launch at login: **System Settings → General → Login Items** → add
`Speaker Control.app`.

The build is ad-hoc signed and produced locally, so Gatekeeper does not prompt.

## How it works

macOS gives the built-in speakers a single volume control and no left/right
slider. This app talks to the CoreAudio HAL directly:

| Purpose | API |
| --- | --- |
| Main volume | `kAudioDevicePropertyVolumeScalar` (output scope) |
| Left/right balance | `kAudioDevicePropertyStereoPan` |
| True mono | `kAudioHardwarePropertyMixStereoToMono` |

### Why the mono downmix is required

Pan on these devices is a **balance** control, not a downmix: it attenuates the
opposite channel instead of summing it. That was confirmed by acoustic
measurement — a tone present only in the right channel drops to the noise floor
when pan is moved fully left. Disabling one speaker with pan alone therefore
loses whatever was in that channel.

`kAudioHardwarePropertyMixStereoToMono` is the public CoreAudio property behind
**Accessibility → Audio → "Play stereo audio as mono"**. It runs inside the audio
driver, so it applies to every app with no extra driver to install.

### Slider mapping

The device uses a *constant-power* pan law: `left gain = cos(p·π/2)`,
`right gain = sin(p·π/2)`. The curve was measured by playing two different tones
(one per channel) and analysing a recording captured with the built-in
microphone; it matches theory within about 0.5 dB. The sliders therefore use its
exact inverse:

```
p = 2/π · atan2(right, left)
```

so *Left 100% / Right 50%* really is a 2:1 ratio, and *Left 100% / Right 0%*
is a full pan to the left.

## Notes

- **Mono is a system-wide setting.** It changes output for the whole system, the
  same as toggling it in System Settings, and coreaudiod persists it in
  `/Library/Preferences/Audio/com.apple.audio.SystemSettings.plist` — so it
  survives restarts until you turn it off again.
- When a side is set to 0%, the panel shows a prompt to enable Mono. The
  **Left Only** / **Right Only** buttons enable it for you; dragging a slider
  does not, so the system setting is never changed behind your back.
- Left/right control needs a device that supports `StereoPan`. Some devices
  (certain Bluetooth adapters, for example) do not — the sliders are then
  disabled and the panel says so in the headline.
- The app follows the default output device, so plugging in headphones switches
  it automatically.

## Layout

```
Sources/
  AudioController.swift   CoreAudio layer: property reads/writes, listeners, pan mapping
  ControlPanel.swift      Menu-bar panel UI
  SpeakerControlApp.swift MenuBarExtra entry point
Resources/
  Info.plist
  AppIcon.icns
build.sh
```
