#!/usr/bin/env bash

set -euo pipefail

# Récupère la MAC sans les :
get_mac_or_default() {
  local mac
  mac=$(ip link | awk '/ether/ {print $2; exit}' | tr -d ':' || true)
  [[ -n "$mac" ]] && echo "$mac" || echo "default"
}

id=$(get_mac_or_default)

# On veut que current → ../hosts/<id>
target="hosts/$id"
symlink_path="hosts/current"
symlink_target="../$target"

# Vérifie que le dossier cible existe
if [[ ! -d "$target" ]]; then
  echo "❌ Le dossier '$target' n'existe pas. Abandon."
  exit 1
fi

# Récupère la cible actuelle du lien
current_link=$(readlink "$symlink_path" 2>/dev/null || echo "")

if [[ "$current_link" == "$symlink_target" ]]; then
  echo "✅ Le lien '$symlink_path' pointe déjà vers '$symlink_target'"
else
  echo "🔁 Correction : le lien '$symlink_path' pointait vers '$current_link', il sera remplacé."
  rm -f "$symlink_path"
  ln -s "$symlink_target" "$symlink_path"
  echo "✅ Lien symbolique mis à jour : $symlink_path → $symlink_target"
fi