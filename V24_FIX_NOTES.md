# V24 Deep Bug Check + Premium GO Border + Logo Cleanup

## GO Button — premium border
- Circular neon border with soft outer glow and subtle depth.
- Border alpha pulses lightly with the existing glow animation.

## Logo cleanup (mport_logo_noborder.png)
- Removed residual white/light background plate behind lettering (area behind T / G).
- Wiped remaining corner artifacts from the old rounded-square frame on all 4 corners.
- Recentered cleaned artwork on a fully transparent 512x512 canvas.
- Kept intentional white/silver fills of the MPorT wordmark and blue metallic logo art.

## Splash — timer lifecycle
- Watchdog / fallback Timers are stored in _watchdogTimer.
- Cancelled on successful navigation and in dispose() to avoid late callbacks after the route is gone.

## Deep review
- Speed-test run isolation via _runId / _testGeneration correctly blocks stale progress after cancel or network change.
- Connectivity subscription, animation controllers, sheet controller, and service listeners are disposed cleanly.
- Server fallback + typed exception handling (cancel / network-change / timeout / TLS) is sound.
