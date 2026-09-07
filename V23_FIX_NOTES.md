# V23 Deep UI / Splash Fix

- Splash video re-encoded to Android-compatible H.264 Constrained Baseline, yuv420p.
- Splash enters immersive full-screen mode and restores edge-to-edge UI on exit.
- Video completion detection uses `isCompleted` plus a duration watchdog.
- GO button now uses a borderless, transparent logo asset; all circular outline containers were removed.
- Android adaptive launcher icon uses a transparent foreground with a dedicated pure-black background, avoiding an opaque black square over the logo border.
- Launcher assets regenerated for mdpi through xxxhdpi.
