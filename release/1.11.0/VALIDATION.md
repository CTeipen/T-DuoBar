# T-DuoBar 1.11.0 (29): validation

Checked on 2026-10-18, macOS 27.2 (26B5112a), Apple Silicon. The user reports
normal repeated-click behavior and ordinary lifecycle behavior in build 29.
The automated full suite passed **352 tests, 0 failures, 6 hardware skips**.

## Short appearance comparison

One running Release process, Classic / Glass / Classic / Glass; 5-second settling
period and 35-second capture per case. Settings remained behind the open menu.
The selected glass transparency was 70%. CUA confirmed the expected window before
and after the first three cases. The fourth case ended at Settings and is excluded. The user did not click but
reported that another agent could have changed focus; the cause is not established.
An accessory was discovered during the first case and remained in later cases.

| Case | App CPU, one core | Median app footprint | Whole WindowServer CPU, one core | Whole GPU utilization, median |
|---|---:|---:|---:|---:|
| Classic 1 | 0.333% | 72.56 MiB | 63.99% | 58% |
| Glass 1 | 0.240% | 69.88 MiB | 64.76% | 67% |
| Classic 2 | 0.298% | 73.97 MiB | 58.56% | 61% |

The sequence took 400 seconds and exceeded the requested approximately four-minute
quiet window. The second Classic case is supplemental: a quiet desktop is not
assumed for that period. A steady open window was checked, not click-to-display
latency. Short observations do not demonstrate a memory optimization or leak freedom.

App CPU was low in these samples. The graphics background was busy in both styles;
WindowServer and IORegistry GPU readings include other applications and UI automation.
**No isolated GPU-cost, wattage, battery-drain or energy-efficiency conclusion is made.**
Power sampling required administrator authentication and was not enabled.

A separate fresh-launch, menu-closed sample measured **0.071% of one core** and a
median **21.50 MiB footprint** over 35 seconds. Its state/cache age differs from
the open-menu process, so it is not a controlled style-memory comparison. MiB is
2^20 bytes; footprint is different from resident memory. CPU counters were
converted from Mach ticks with mach_timebase_info before taking deltas.

## Lifecycle and memory checks

An optimized native harness used the production VPN reader, observer and service
with read-only real system calls: **500 starts/reads/stops, 500 successful reads,
0 observer failures, 0 unexpected cached-state resets**. Setup plus read latency:
p50 5.21 ms, p95 6.00 ms, maximum 15.21 ms. This is service latency, not UI latency.
In the five seconds after stop, the harness used 0.00014 CPU seconds.

Native tests cover actual popup visibility, observer start/stop, cancellation,
late results, coalescing, background tint, shared content across styles, outside
clicks, Escape and late close events. The status-button controller is exercised
through 30 repeated down/up cycles. Wake refresh wiring was inspected: it refreshes
the existing store; an inactive VPN service does not start observing. No sleep was
forced and no VPN connection was toggled during this audit.

A permissions-limited Release `leaks` scan after UI automation reported 177 objects
/ 8,496 bytes, with roots named NSAccessibilityCustomAction and AppKit toolbar
accessibility handlers. A fresh-launch scan reported zero. Attribution and long-run
behavior are not established; this is not proof that all memory is leak-free.

## Reproduction and limits

Sanitized numerical results: [.ecc/benchmarks/t-duobar-1.11.0-macos.json](../../.ecc/benchmarks/t-duobar-1.11.0-macos.json).
Read-only sampler sources are in [script/diagnostics](../../script/diagnostics).
Local raw traces and result bundles are retained under ignored build/release-1.11.0
and build/status-click-fix. Process sampling of WindowServer via libproc was denied;
its CPU was instead derived from cumulative `ps time` and wall-time deltas.
GPU data is a driver-dependent IORegistry gauge, not app-attributed GPU power.

Runtime checks ran on Apple Silicon. Intel compiled but was not physically tested.
There is no induced sleep/wake cycle, forced VPN reconnect, multi-hour soak or
exhaustive accessory/macOS coverage. The distribution remains experimental,
ad-hoc signed, without Developer ID signing or Apple notarization.
