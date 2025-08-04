#!/usr/bin/env bash
set -euo pipefail

###############
# CONFIG / VARS
###############
SECRET_BIN="${SECRET_BIN:-docker}"
CLIP_CMD=""                 # détecté plus bas
AUDIT_FILE="${HOME}/.docker_secret_audit.log"
DEFAULT_LEN=32              # longueur des mots de passe générés
VERSION_DELIM="@"           # séparateur nom@version

#################
# UTILITAIRES
#################
die() { echo "$*" >&2 ; exit 1; }

timestamp() { date -Iseconds; }

log_audit() {   # $1 action $2 nom $3 commentaire
  printf '%s\n' "{\"ts\":\"$(timestamp)\",\"user\":\"${USER}\",\"action\":\"$1\",\"secret\":\"$2\",\"comment\":\"${3:-}\"}" >> "$AUDIT_FILE"
}

generate_password() { openssl rand -base64 "$DEFAULT_LEN" | tr -d '\n'; }

show_help() {
cat <<EOF
Usage: $0 [OPTIONS] [SECRET_NAME] [SECRET_VALUE]

Crée / remplace un secret Docker Swarm avec versioning, audit, rotation.

Options :
  -g, --generate        Génère un mot de passe (ne demande pas de saisie)
  -v, --verbose         Affiche la valeur générée
  -c, --clipboard       Copie la valeur dans le presse-papiers (auto-détecté)
  -f FILE, --from-file  Un secret par ligne au format login:password
  -t COMMENT            Tag court (commentaire) stocké en label
  -r, --rotate          Incrémente le numéro de version et met à jour
  -h, --help            Cette aide

STDIN non-TTY : lit la valeur sur stdin (pipe-friendly)
EOF
}

#################
# DETECTION CLIP
#################
if [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
  CLIP_CMD=(xclip -selection clipboard)
elif [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
  CLIP_CMD=(wl-copy)
fi

#################
# PARSE OPTS
#################
GEN=false VERBOSE=false ROTATE=false FROM_FILE=""
TAG_COMMENT=""
CLIPBOARD=false

OPTS=$(getopt -o gvrcf:t:h --long generate,verbose,clipboard,from-file:,tag:,rotate,help -- "$@") || { show_help; exit 1; }
eval set -- "$OPTS"

while true; do
  case "$1" in
    -g|--generate) GEN=true ; shift ;;
    -v|--verbose)  VERBOSE=true ; shift ;;
    -c|--clipboard) CLIPBOARD=true ; shift ;;
    -f|--from-file) FROM_FILE="$2"; shift 2 ;;
    -t) TAG_COMMENT="$2" ; shift 2 ;;
    -r|--rotate) ROTATE=true ; shift ;;
    -h|--help) show_help ; exit 0 ;;
    --) shift ; break ;;
  esac
done

#################
# FONCTION CENTRALE
#################
create_secret() {
  local name="$1"
  local value="$2"
  local comment="${3:-}"

  # Supprime ancien s'il existe
  if docker secret ls --format '{{.Name}}' | grep -q "^${name}$"; then
    echo "Secret '$name' existe → suppression."
    docker secret rm "$name"
  fi

  # labels
  local labels=(
    "created=$(timestamp)"
    "user=${USER}"
  )
  [[ -n "$comment" ]] && labels+=("comment=${comment}")

  local label_args=()
  for l in "${labels[@]}"; do label_args+=(--label "$l"); done

  echo -n "$value" | \
    docker secret create "${label_args[@]}" "$name" - >/dev/null

  echo "Secret '$name' créé."
  log_audit "create" "$name" "$comment"
}

#################
# ROTATION
#################
resolve_name() {
  local base="$1"
  if ! $ROTATE; then
    echo "$base"
    return
  fi

  # cherche la dernière version
  local last=$(docker secret ls --format '{{.Name}}' | grep -E "^${base}${VERSION_DELIM}[0-9]+$" | sort -t"${VERSION_DELIM}" -k2 -nr | head -n1)
  local next=1
  if [[ -n "$last" ]]; then
    next=$((${last##*${VERSION_DELIM}} + 1))
  fi
  echo "${base}${VERSION_DELIM}${next}"
}

#################
# FROM-FILE
#################
process_file() {
  [[ ! -r "$FROM_FILE" ]] && die "Fichier introuvable ou illisible : $FROM_FILE"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    login="${line%%:*}"
    password="${line#*:}"
    [[ "$login" == "$password" ]] && password=""   # pas de « : »

    if [[ -z "$password" ]]; then
      if $GEN; then
        password=$(generate_password)
      else
        die "Mot de passe manquant pour $login et -g non activé"
      fi
    fi

    local full_name
    full_name=$(resolve_name "$login")
    create_secret "$full_name" "$password" "$TAG_COMMENT"
    $VERBOSE && echo "  $login  <ab>  $password"
    if $CLIPBOARD && [[ -n "$CLIP_CMD" ]]; then
      printf '%s' "$password" | "${CLIP_CMD[@]}" 2>/dev/null
    fi
  done < "$FROM_FILE"
}

#################
# MODE STDIN / ARGUMENTS
#################
if [[ -n "$FROM_FILE" ]]; then
  process_file
  exit 0
fi

# Lecture nom
SECRET_NAME="${1:-}"
if [[ -z "$SECRET_NAME" ]]; then
  [[ -t 0 ]] && read -rp "Nom du secret : " SECRET_NAME
  [[ -z "$SECRET_NAME" ]] && die "Nom du secret requis."
fi
shift || true

# Lecture valeur
if $GEN; then
  SECRET_VALUE=$(generate_password)
elif [[ $# -gt 0 ]]; then
  SECRET_VALUE="$1"
elif [[ ! -t 0 ]]; then
  # pipe-friendly
  SECRET_VALUE=$(cat)
else
  # prompt
  read -rsp "Valeur du secret (vide = générer si -g) : " SECRET_VALUE
  echo
fi

if [[ -z "$SECRET_VALUE" ]]; then
  if $GEN; then
    SECRET_VALUE=$(generate_password)
  else
    die "Valeur du secret vide et -g non activé."
  fi
fi

FULL_NAME=$(resolve_name "$SECRET_NAME")
create_secret "$FULL_NAME" "$SECRET_VALUE" "$TAG_COMMENT"

$VERBOSE && echo "Valeur du secret : $SECRET_VALUE"
if $CLIPBOARD && [[ -n "$CLIP_CMD" ]]; then
  printf '%s' "$SECRET_VALUE" | "${CLIP_CMD[@]}" 2>/dev/null
fi

