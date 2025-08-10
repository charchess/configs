#!/usr/bin/env bash

VIP="192.168.200.60"  # Ton VIP
PORT=9091

if curl -s --max-time 2 "http://${VIP}:${PORT}/" \
    | jq -e '.["disk.feature.nfs"] == "true" and .["cpu.feature.avx"] == "true"' >/dev/null; then
  exit 0
else
  exit 1
fi