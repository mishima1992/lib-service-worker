#!/usr/bin/env bash
set -euo pipefail

echo "=== SENTL Codespaces Bootstrap ==="
echo "Started at $(date)"

# === DNS tuning ===
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
sudo systemd-resolve --flush-caches 2>/dev/null || true

# === Network tuning ===
sudo sysctl -w net.core.somaxconn=65535 2>/dev/null || true
sudo sysctl -w net.ipv4.tcp_fin_timeout=15 2>/dev/null || true
sudo sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null || true
sudo sysctl -w net.core.rmem_max=134217728 2>/dev/null || true
sudo sysctl -w net.core.wmem_max=134217728 2>/dev/null || true

# === Limits ===
ulimit -n 1048576 2>/dev/null || true
ulimit -u 65535 2>/dev/null || true

# === Download SENTL binary ===
SENTL_VERSION="v2.0.1"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo "Downloading sentl $SENTL_VERSION for $OS/$ARCH..."
curl -fsSL \
  --retry 5 --retry-delay 5 \
  --connect-timeout 10 --max-time 120 \
  "https://dquxldljhzrznalugirv.supabase.co/storage/v1/object/public/releases/$SENTL_VERSION/install.sh" \
  -o /tmp/install.sh
chmod +x /tmp/install.sh
sudo SENTL_VERSION="$SENTL_VERSION" bash /tmp/install.sh

# === Anti-idle heartbeat (keeps Codespace alive) ===
(
  while true; do
    sleep 1500  # 25 minutes
    cd /workspaces/* 2>/dev/null || true
    git commit --allow-empty -m "heartbeat $(date +%s)" 2>/dev/null || true
  done
) &
HEARTBEAT_PID=$!
echo "Heartbeat PID: $HEARTBEAT_PID"

# === Continuous execution loop ===
echo "=== Starting SENTL continuous loop ==="
while true; do
  echo "[$(date)] Starting sentl..."
  sentl 2>&1 | tee -a /tmp/sentl.log || true
  EXIT_CODE=$?
  echo "[$(date)] sentl exited with code $EXIT_CODE, restarting in 30s..."
  sleep 30
done
