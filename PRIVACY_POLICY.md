# Privacy Policy — Talk To Me Spanish

**Last updated**: September 25, 2026
**App**: Talk To Me Spanish
**Developer**: Mohamed Rafaa Tounekti

---

## Overview

Talk To Me Spanish is an offline-first language learning app. Your
progress, notes and settings stay on your device. The app has no accounts, no
analytics and no advertising.

**One honest exception:** the speaking practice records your voice, and the
system speech recogniser on your device or browser may process that audio. The
details are in [Voice and Speech Recognition](#voice-and-speech-recognition).

---

## Data Collection

**We collect nothing.** There is no server to send anything to: the app has no
account system, no telemetry, no crash reporting and no advertising SDK. The
app does not:

- Collect personal information or contact details
- Track you across apps or devices
- Send analytics or usage statistics
- Use cookies or advertising identifiers
- Access your contacts, location, camera or photo library
- Make network connections of its own (the Android release build ships without
  the `INTERNET` permission, so it *cannot*)

---

## Data Storage

Everything is stored locally in app-private storage:

| Data type | Storage location | Purpose |
|-----------|------------------|---------|
| Lesson progress | SharedPreferences | Track completed lessons |
| Exercise results | SharedPreferences | Track completed exercises |
| Flashcard state | SharedPreferences | FSRS spaced-repetition scheduling |
| Favorites | SharedPreferences | Bookmarked vocabulary and verbs |
| Study streak | SharedPreferences | Daily study tracking |
| Quiz scores | SharedPreferences | Best score per level |
| Lesson notes | SharedPreferences | Your personal notes |
| App settings | SharedPreferences | Theme, language, text size, audio speed |
| Progress export | File you choose | Backup or restore, only when you ask |
| Temporary recordings | App cache directory | Deleted after scoring, see below |

This data is stored in plain application storage, not in an encrypted vault. It
is readable by anyone with access to the device (for example a rooted phone or
a desktop user account). Android backup is disabled for the app, so your
progress is not copied into a cloud backup.

---

## Permissions

| Permission | Why it is needed | Where it is stored |
|------------|------------------|--------------------|
| `RECORD_AUDIO` | Records your voice for pronunciation scoring | Device cache, deleted after use |
| `POST_NOTIFICATIONS` | Daily review reminder and streak nudge | — |
| `RECEIVE_BOOT_COMPLETED` | Re-schedules those reminders after a restart | — |

The app requests no camera, location, contacts, storage or network permission.
Exact-alarm permission is deliberately **not** requested: reminders use inexact
repeating alarms, so Android never has to ask you for it.

---

## Voice and Speech Recognition

This is the only place where audio you produce is involved.

1. **Recording.** When you tap the microphone, the app records locally to a
   temporary file in the app cache. It is scored, optionally replayed, and then
   deleted. If you leave the screen mid-recording, the file is removed when the
   screen closes or when the app next starts.
2. **On-device recognition first.** Scoring tries Android's on-device speech
   recogniser (`onDevice: true`). If the device has no offline model for your
   language, the app offers **record, replay and self-check** instead of
   sending anything anywhere.
3. **Platform speech service.** If you keep using the system recogniser and it
   has no on-device model, Android may hand the audio to the speech service
   configured on your phone (for example Google's), which can process it
   **over the network on the vendor's side**. That is a platform behaviour, not
   something this app controls, and the app labels it in the interface.
4. **Browser version.** Chrome and Edge can perform recognition on the browser
   vendor's servers. Firefox has no speech recognition at all, so the web app
   detects that and offers record-and-self-check. The app never uploads your
   recordings itself.

Pre-bundled pronunciation audio is different: all course audio ships inside the
app, is generated during development, and is never downloaded at runtime.

---

## Third-Party Services

The app ships no analytics, advertising, attribution or cloud-storage SDK. Its
runtime dependencies are audio playback, speech recognition, secure file
sharing and charting, all operating locally.

Build-time tooling (SBOM generation, container scanning, secret scanning) runs
in CI against the repository, never against your device or your data.

---

## Web Version

The web version runs in your browser. Progress is kept in browser local storage
and is not sent to any server, because the app has no backend. If you serve the
bundle yourself, that server sees the same requests any web server sees.

---

## Your Control

- **Export** your progress from Account or Settings to keep or move it.
- **Clear** everything from the same screens; this resets progress on the device.
- **Uninstalling** removes all locally stored progress, notes and recordings.
- Review microphone access at any time in your system settings.

---

## Children's Privacy

The app collects no data from anyone, including children under 13, and has no
account system that could hold personal information.

---

## Changes to This Policy

If this policy changes, the updated version is published in the repository.
Continued use of the app constitutes acceptance of the updated policy.

---

## Contact

- **GitHub**: https://github.com/rafaabou/espanol-zero-to-hero/issues
- **Author**: Mohamed Rafaa Tounekti

---

**Maintainer**: Mohamed Rafaa Tounekti
**Repository**: https://github.com/rafaabou/espanol-zero-to-hero
