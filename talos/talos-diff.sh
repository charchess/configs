#!/bin/bash
# talos-diff.sh – compare YAML du cluster vs dossier ou fichier
set -uo pipefail

usage() {
  echo "Usage: $0 [-d dossier] [-f fichier] [-a]"
  echo "  -d dossier   dossier contenant les YAML (par défaut : manifests)"
  echo "  -f fichier   fichier YAML unique à comparer"
  echo "  -a           compare tous les fichiers du dossier (défaut)"
  exit 1
}

DOSSIER="manifests"
FICHIER=""

while getopts ":d:f:a" opt; do
  case $opt in
    d) DOSSIER="$OPTARG" ;;
    f) FICHIER="$OPTARG" ;;
    a) FICHIER="" ;; # rien à faire, on veut le dossier
    *) usage ;;
  esac
done

GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $*"; }

# construction de la liste
if [[ -n $FICHIER ]]; then
  files=("$FICHIER")
else
  files=("$DOSSIER"/*.yaml "$DOSSIER"/*.yml)
fi

log "Scan …"
total_docs=0
total_diffs=0

for file in "${files[@]}"; do
  [[ ! -f $file ]] && continue
  docs=$(yq eval-all 'length' "$file" | awk 'NR==1{print $1}')
  for ((idx=0; idx<docs; idx++)); do
    local=$(yq eval-all -P "select(documentIndex==$idx)" "$file")
    [[ -z $local || "$local" == "null" ]] && continue

    kind=$(echo "$local" | yq eval '.kind' -)
    name=$(echo "$local" | yq eval '.metadata.name' -)
    ns=$(echo "$local" | yq eval '.metadata.namespace // ""' -)
    [[ -z $kind || -z $name ]] && continue

    if kubectl get "$kind" "$name" ${ns:+-n "$ns"} &>/dev/null; then
      live=$(kubectl get "$kind" "$name" ${ns:+-n "$ns"} -o yaml \
             | yq eval 'del(.metadata.resourceVersion,
                            .metadata.uid,
                            .metadata.generation,
                            .metadata.creationTimestamp,
                            .metadata.labels."kubernetes.io/metadata.name",
                            .status,
                            .spec.finalizers)' -)
      log "Comparaison $kind/$name dans $(basename "$file") …"
      diff -u <(echo "$local") <(echo "$live") | tail -n +3 || true
      ((total_diffs++))
    else
      log "$(basename "$file") absent dans le cluster"
    fi
    ((total_docs++))
  done
done

log "TOTAL : $total_docs documents vérifiés, $total_diffs différences."

