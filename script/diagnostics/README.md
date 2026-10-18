# Read-only macOS sampling

These optional CLI tools are diagnostics, not part of the app or background services.
Compile with the Xcode command-line tools:

```sh
clang -O2 -Wall -Wextra script/diagnostics/profile_process.c -o /tmp/duobar-process-usage
clang -O2 -Wall -Wextra -framework IOKit -framework CoreFoundation script/diagnostics/profile_gpu.c -o /tmp/duobar-gpu-usage
/tmp/duobar-process-usage APP_PID 35 > process.ndjson
/tmp/duobar-gpu-usage 35 > gpu.ndjson
```

The process tool accepts PID, duration (1–3600 seconds) and optional interval
(0.1–5 seconds, default 1). It rejects PID reuse and converts Mach CPU counters
using the machine's timebase. Compute one-core CPU percent as 100 × cumulative
CPU-seconds delta / wall-seconds delta. Footprint and resident bytes are different
metrics; use MiB = 2^20 bytes. Other-user process access may be denied.

The GPU tool samples the first IOAccelerator's driver-dependent PerformanceStatistics
keys. Missing values are null. Values describe the whole GPU, not DuoBar's share,
and do not measure watts or battery drain. Use identical visible-window conditions,
settling periods, repetition and a quiet desktop; record whether the window really
stayed open. Neither helper installs anything or changes system settings.
