#!/bin/sh


docker service inspect $(docker service ls -q) \
  --format '{{range $k,$v := .Spec.Labels}}{{printf "%s=%s\n" $k $v}}{{end}}' \
  | grep -oP 'traefik\.http\.routers\..*\.rule=.*Host\(`\K[^`]+' \
  | while read -r host; do
      printf "%-40s " "$host"
      dig +short @"8.8.8.8" "$host" A | head -1 >/dev/null 2>&1 \
        && printf "✅\n" \
        || printf "❌\n"
    done