# 10-run hidden replay loop

Restricted evaluator-only raw logs live in `*_run_*.log` and `*_pub_get.log`. Summary JSON records exit-code outcomes only.

Reference is expected to pass all 10 hidden runs. Baseline and all five fresh solver reruns are expected to fail hidden verification for this failed-candidate slice.
