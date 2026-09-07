# V24 Deep Bug Check + Premium GO Border

## GO Button — premium border
- Restored a refined multi-layer circular border on the GO button (outer ring + inner depth ring + soft radial fill).
- Border alpha pulses lightly with the existing glow animation for a polished, professional look.
- Logo remains the borderless asset (`mport_logo_noborder.png`) so artwork and UI rings do not conflict.
- Outer ambient glow retained and slightly strengthened for presence.

## Splash — timer lifecycle
- Watchdog / fallback `Timer`s are now stored in `_watchdogTimer`.
- Cancelled on successful navigation and in `dispose()` to avoid late callbacks after the route is gone.

## Deep review (no further code changes required)
- Speed-test run isolation via `_runId` / `_testGeneration` correctly blocks stale progress after cancel or network change.
- Connectivity subscription, animation controllers, sheet controller, and service listeners are disposed cleanly.
- Server fallback + typed exception handling (cancel / network-change / timeout / TLS) is sound.
- No debug prints or unfinished TODOs left in the critical path.
