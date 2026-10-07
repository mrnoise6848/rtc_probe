# Performance budget

One overlap-safe sampler runs at 1 Hz. Slow pulls are skipped; no queue of stats requests. Cancellation does not reset an in-flight lock. Late results are ignored after teardown. Missing stats reset delta baselines and clear live values.

Timeline holds 600 points; the dashboard copies only the trailing 60 seconds. Event history holds 200 entries. Whole-session summary uses five constant-memory accumulators, so chart eviction does not corrupt averages. Diagnostics store at most one active finding per code. Widgets have no continuous animation or chart dependency; events/details use lazy lists where applicable.

No raw-report serialization, media persistence or external telemetry. Device path queries occur at session start/resume only. This is a design budget, not a measured CPU or battery benchmark. Release profiling on physical Android/iOS devices remains required for quantitative claims.
