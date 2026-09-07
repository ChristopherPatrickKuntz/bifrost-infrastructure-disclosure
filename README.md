<p align="center">
  <img src="https://img.shields.io/badge/Severity-CRITICAL-red?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Auth_Required-NONE-red?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Checks_Passed-58%2F58-brightgreen?style=for-the-badge" />
  <img src="https://img.shields.io/badge/CVEs-16-orange?style=for-the-badge" />
</p>

# Bifrost Finance — Critical Infrastructure Compromise

### Zero Authentication to Full Kubernetes Root + Cloud Account Access

| | |
|---|---|
| **Target** | stats.bifrost.io → app.bifrost.io shared infrastructure |
| **Platform** | [Immunefi](https://immunefi.com) |
| **Severity** | Critical |
| **Authentication** | None required |
| **Date** | February 27, 2026 |
| **Author** | Christopher Patrick Kuntz |

**Documentation updated:** 2026-09-07. The recorded Immunefi submission is dated February 2026; no newer vendor outcome is recorded in this README.

---

## Summary

An unauthenticated attacker can achieve **full root access** on the Bifrost Kubernetes production node and subsequently **full cluster administrator** privileges, compromising the entire infrastructure including databases, cloud accounts, container registries, CI/CD, and blockchain collator nodes.

```
Internet (zero auth)
  → Grafana API (anonymous access)
    → PostgreSQL superuser (datasource proxy)
      → OS command execution (COPY TO PROGRAM)
        → 19 databases across 4 hosts (dblink lateral movement)
          → K8s pod shell (RCE via chained dblink)
            → Container escape boundary (CVE-2022-34918, all prerequisites proven)
              → Host root → Cluster admin → Cloud account
```

---

## Impact

| Category | Detail |
|----------|--------|
| **Remote Code Execution** | Arbitrary commands on Docker host + 15 K8s database pods |
| **Databases Compromised** | 19 PostgreSQL instances, all with superuser + RCE |
| **User PII Exposed** | 132,980 wallet-to-Twitter identity mappings |
| **Container Escape** | 9 applicable CVEs, all prerequisites verified live |
| **Kubernetes Cluster** | 42 pods enumerated, 10 privileged pods identified |
| **Cloud Account** | Tencent Cloud CBS/CFS API key secrets referenced |
| **Blockchain** | 9 collator nodes, transaction material endpoint accessible |
| **Supply Chain** | Harbor registry (16 repos) + Jenkins CI/CD reachable |

---

## Repository Structure

```
.
├── README.md                         You are here
├── EXPLOIT-PROOF.md                  Complete end-to-end writeup (1,158 lines)
│                                     12 sections covering entry → escape → blast radius
│
├── scripts/
│   ├── full-chain-poc.sh             ONE-FILE proof of concept
│   │                                 Run this — 58 automated checks, zero auth required
│   ├── deliver.py                    Exploit binary delivery automation
│   ├── stage1_recon.sh               Kernel offset extraction
│   ├── stage2_deploy.sh              Binary deployment to pod
│   ├── serve.sh                      HTTP server for binary hosting
│   └── EXECUTE.md                    Step-by-step manual execution guide
│
├── exploit-src/
│   ├── Makefile                      Build system (static ELF binaries)
│   ├── poc                           Compiled CVE-2022-34918 exploit (768 KB, static)
│   ├── get_root                      Post-escape payload (805 KB, static)
│   ├── src/
│   │   ├── main.c                    Core exploit: heap overflow → modprobe_path
│   │   ├── modprobe.c                Privilege escalation via modprobe hijack
│   │   ├── nf_tables.c              nf_tables netlink operations
│   │   ├── keyring.c                 Heap spray: keyring API
│   │   ├── uring.c                   Heap spray: io_uring
│   │   ├── simple_xattr.c           Heap spray: extended attributes
│   │   ├── netlink.c                 Netlink message construction
│   │   └── util.c                    Namespaces, CPU affinity, helpers
│   ├── inc/                          Header files (8 files)
│   └── get_root_src/
│       └── get_root.c                Host root proof + K8s token extraction
│
└── logs/
    ├── JOURNEY-LOG.md                Live recon Part 1: kernel, mounts, security posture
    ├── JOURNEY-LOG-2.md              Live recon Part 2: SA token, Harbor, kallsyms
    └── JOURNEY-LOG-3.md              Live recon Part 3: 42 pods, cloud metadata, secrets
```

---

## Quick Start — Verify the Vulnerability

### Prerequisites

- `bash`, `curl`, `python3` on your machine
- Network access to `stats.bifrost.io`
- No authentication, tokens, or API keys needed

### Run

```bash
bash scripts/full-chain-poc.sh
```

This executes 23 steps and 58 checks — from anonymous Grafana access through RCE, lateral movement across 19 databases, K8s pod enumeration, and container escape prerequisite verification. All read-only. Cleans up after itself.

---

## CVEs — Kernel 5.4.119-19-0009.3

16 CVEs affect the target kernel. 9 enable container escape from an unprivileged pod.

### Container Escape (all prerequisites verified live)

| CVE | CVSS | Subsystem | Status |
|-----|------|-----------|--------|
| **CVE-2022-34918** | 7.8 | nf_tables heap overflow | **PRIMARY — exploit compiled** |
| CVE-2022-0185 | 8.4 | VFS legacy_parse_param | All prerequisites met |
| CVE-2021-22555 | 7.8 | Netfilter xt_compat | All prerequisites met |
| CVE-2022-29582 | 7.0 | io_uring UAF | All prerequisites met |
| CVE-2023-32233 | 7.8 | nf_tables UAF | All prerequisites met |
| CVE-2022-2588 | 7.8 | cls_route UAF | All prerequisites met |
| CVE-2022-25636 | 7.8 | nf_tables OOB write | All prerequisites met |
| CVE-2023-35001 | 7.8 | nf_tables OOB r/w | All prerequisites met |
| CVE-2022-1116 | 7.8 | io_uring integer overflow | All prerequisites met |

### Additional LPE

CVE-2022-0995, CVE-2022-1015, CVE-2022-2639, CVE-2022-27666, CVE-2023-0386, CVE-2023-2235, CVE-2023-3269

Full details with fix versions, prerequisites, and public exploit references in [EXPLOIT-PROOF.md](EXPLOIT-PROOF.md#7-all-cves--kernel-54119-19-00093-tencent-tke).

---

## What Was Proven vs. What Was Not Executed

<table>
<tr><th>Proven Live (✅)</th><th>Not Executed — Responsible Disclosure (❌)</th></tr>
<tr><td>

- Anonymous Grafana API access
- SQL execution as PostgreSQL superuser
- RCE on Docker host + K8s pods
- Credential extraction (22 passwords)
- Lateral movement to 19 databases
- 132,980 PII records accessible
- Container security posture (Seccomp=0)
- Kernel config + loaded modules
- All exploit primitives (userfaultfd, netlink, io_uring)
- Host filesystem write via bind mount
- Binary delivery to pod
- 42 pods enumerated via kubelet API
- 10 privileged pods detailed
- Tencent Cloud metadata (PRODUCTION)
- Cloud API key secrets identified
- Exploit compiled for target kernel
- Exploit delivery chain tested

</td><td>

- Kernel heap overflow trigger
- Container escape to host root
- K8s cluster takeover
- Cloud API key extraction
- Data modification or exfiltration
- Persistence installation
- Collator key access

</td></tr>
</table>

---

## Responsible Disclosure

The container escape exploit was **not triggered** on the production system. Kernel heap corruption on a node running 42 pods risks:
- Kernel panic and service disruption
- Memory corruption in other pods
- Unpredictable behavior in kube-system pods

All evidence demonstrates the escape **will succeed** — every prerequisite is met, the exploit targets the exact kernel version, and the delivery chain is proven end-to-end.

---

## Documentation

| Document | Description |
|----------|-------------|
| [EXPLOIT-PROOF.md](EXPLOIT-PROOF.md) | Complete 12-section writeup with all evidence |
| [scripts/EXECUTE.md](scripts/EXECUTE.md) | Manual execution guide |
| [logs/](logs/) | Raw command output from live reconnaissance |

---

<p align="center">
  <sub>Submitted via Immunefi — February 2026</sub>
</p>
