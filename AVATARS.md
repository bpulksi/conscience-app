# Avatar layer (persona = data)

A personality is a folder, not a class:

```
flutter/android/app/src/main/assets/avatars/<id>/persona.json
```

Built-in cast: `coach` (firm, escalates fast), `monk` (calm, one question, slow),
`joker` (sarcastic). Adding a fourth avatar means adding a folder — no Kotlin.

## persona.json

| field | meaning |
|---|---|
| `id`, `name`, `tone` | identity shown on the Cast screen |
| `voiceId` | reserved for TTS, unused while text-only |
| `animations` | Lottie path per stage (`zen`/`impatient`/`furious`/`enough`) |
| `thresholds` | fraction of the daily limit where the stage flips (ENOUGH = limit reached) |
| `cadence.minGapSeconds` | minimum gap between two lines |
| `cadence.maxLinesPerDay` | hard cap — the anti-nagging rule |
| `cadence.bubbleSeconds` | how long the speech bubble stays |
| `lines` | 6–10 lines per stage, shuffled without repeat |

## What changed in the native layer

- **AvatarPersona.kt** — model + `assets` loader + registry (`listIds`, `loadOrDefault`) + `stageFor(fraction)` so thresholds are per-persona.
- **MessageEngine.kt** — whether/when the avatar speaks: stage changes only, `minGapSeconds` between lines, `maxLinesPerDay` cap, shuffle-without-repeat per stage, 30-minute mute persisted in SharedPreferences.
- **OverlayManager.kt** — overlay v2: Lottie + speech bubble, drag by movement (12 px slop), tap = mute 30 min, animation resolved per persona with fallback to `avatars/brain/zen.json`.
- **overlay_avatar.xml** — column: bubble (2 lines, auto-dismiss) + 80dp avatar inside a drag area. `FLAG_NOT_FOCUSABLE` kept.
- **ConscienceAccessibilityService.kt** — the 30 s poll is gone. It schedules one wake-up at the next threshold boundary (capped at 15 min so a restart re-anchors), emits `ZEN → IMPATIENT → FURIOUS → ENOUGH`, and writes to Firestore at `ENOUGH`. Usage now persists across service restarts; per-app limits supported via `setPerAppLimits`.
- **AvatarChannel.kt** — `conscience/avatars` channel: `list`, `selected`, `select`, `sampleLine`, `mute`, `muteStatus`.
- **flutter/lib/services/avatar_cast_service.dart** + **flutter/lib/screens/avatar_cast_screen.dart** — the Cast screen: pick an avatar, hear a sample line, mute.

Register the channel in `MainActivity.configureFlutterEngine`:

```kotlin
AvatarChannel.register(engine.dartExecutor.binaryMessenger, this)
```

## Not done yet (deliberate)

- **No Lottie artwork.** `persona.json` names `avatars/<id>/*.json` but only `avatars/brain/*` exists, so every persona currently falls back to the brain animation and logs a warning. The bubble, lines and cadence all work without it — the artwork is a download, not a build step.
- **Voice.** Text only. When it comes, speak the `enough` line only.
- **Cloud Function `avatarSpeak`.** Static lines ship first; the LLM waits until the log says the static lines land.
- **iOS.** Overlay is Android-only; iOS keeps the Screen Time shield + notification.
- **Nothing here has been compiled** — there is no Flutter/Android SDK on the machine this was written on. Treat it as a reviewed patch, not a green build.
