#!/usr/bin/env bash
# This project was developed with assistance from AI tools.
#
# Generate a self-signed TLS certificate for the OpenClaw gateway proxy.
# The cert includes the desktop LAN IP as a SAN so phones can connect via HTTPS.
#
# Usage: bash scripts/gen-tls-cert.sh [IP]
#   IP defaults to the first non-loopback IPv4 address.

set -euo pipefail

IP="${1:-$(hostname -I | awk '{print $1}')}"
TLS_DIR="$(cd "$(dirname "$0")/.." && pwd)/tls"

mkdir -p "$TLS_DIR"

echo "Generating self-signed cert for $IP"

openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -days 365 -nodes \
    -subj "/CN=openclaw-gateway" \
    -addext "subjectAltName=IP:$IP,IP:127.0.0.1" \
    -keyout "$TLS_DIR/key.pem" \
    -out "$TLS_DIR/cert.pem" \
    2>/dev/null

chmod 600 "$TLS_DIR/key.pem"
chmod 644 "$TLS_DIR/cert.pem"

echo "Certificate written to $TLS_DIR/"
echo "  cert.pem  (share this with your phone to trust it)"
echo "  key.pem   (private key, stays on this machine)"
echo ""
echo "SAN: IP:$IP, IP:127.0.0.1"
echo "Expires: $(openssl x509 -in "$TLS_DIR/cert.pem" -noout -enddate | cut -d= -f2)"
