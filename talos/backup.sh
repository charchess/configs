#!/bin/bash
# talos-manager.sh – Backup / Restore Talos (compatible vieilles CLI)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${SCRIPT_DIR}/talos-backups"
NODES="192.168.200.60"            # IP (ou liste) du/des nœuds
TALOS_CONFIG="${TALOS_CONFIG:-$HOME/.talos/config}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error(){ echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---------- Backup ----------
backup_talos() {
    local comment="${1:-}" type="${2:-full}" ts=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$BACKUP_ROOT/$ts"; mkdir -p "$backup_dir"
    [[ -n $comment ]] && echo "$comment" >"$backup_dir/comment.txt"

    log "🔄 Début backup ($type) vers $backup_dir"

    case "$type" in
        full|all)
            log "📦 Backup complet…"
            talosctl -n "$NODES" get machineconfig -o json | jq -r '.spec' > "$backup_dir/controlplane-config.yaml"
            
            # Snapshot etcd (syntaxe compatible vieilles CLI)
            log "🗄️  Snapshot etcd…"
            talosctl -n "$NODES" etcd snapshot "$backup_dir/etcd-snapshot.db" 2>/dev/null || {
                warn "Échec snapshot API – copie directe /var/lib/etcd/member/snap/db"
                talosctl -n "$NODES" cp /var/lib/etcd/member/snap/db "$backup_dir/etcd-snapshot.db" \
                    2>/dev/null || warn "Copie directe impossible – etcd non accessible"
            }

            kubectl get all --all-namespaces -o yaml >"$backup_dir/k8s-resources.yaml"
            kubectl get crd -o yaml >"$backup_dir/crds.yaml"
            kubectl get secrets --all-namespaces -o yaml >"$backup_dir/secrets.yaml"
            talosctl -n "$NODES" get members -o yaml >"$backup_dir/members.yaml"
            talosctl -n "$NODES" stats >"$backup_dir/node-stats.txt"
	    talosctl -n "$NODES" image list > "$backup_dir/installed-images.yaml"
            ;;
        config)
            log "⚙️  Configuration uniquement…"
            talosctl -n "$NODES" get machineconfig -o yaml >"$backup_dir/controlplane-config.yaml"
            ;;
        etcd)
            log "🗄️  Etcd uniquement…"
            talosctl -n "$NODES" etcd snapshot "$backup_dir/etcd-snapshot.db"
            ;;
        manifests)
            log "📋 Manifests uniquement…"
            kubectl get all --all-namespaces -o yaml >"$backup_dir/k8s-resources.yaml"
            kubectl get crd -o yaml >"$backup_dir/crds.yaml"
            ;;
        *) error "Type inconnu : $type" ;;
    esac

    cat >"$backup_dir/backup-info.json" <<EOF
{"timestamp":"$ts","type":"$type","comment":"$comment","nodes":"$NODES","size":"$(du -sh $backup_dir|cut -f1)"}
EOF
    log "✅ Backup terminé : $backup_dir"
}

# ---------- Restauration ----------
restore_talos() {
    local src="$1" mode="${2:-full}"
    [[ ! -e $src ]] && error "Source introuvable : $src"
    log "🔄 Restauration ($mode) depuis $src"

    case "$mode" in
        full)
            [[ -f $src/controlplane-config.yaml ]] && talosctl -n "$NODES" apply-config -f "$src/controlplane-config.yaml"
            if [[ -f $src/etcd-snapshot.db ]]; then
                warn "⚠️  La restauration etcd redémarre le cluster !"
                read -rp "Continuer ? [y/N] " && [[ $REPLY =~ ^[Yy]$ ]] || exit 0
                talosctl -n "$NODES" etcd snapshot restore "$src/etcd-snapshot.db"
            fi
            [[ -f $src/k8s-resources.yaml ]] && kubectl apply -f "$src/k8s-resources.yaml"
            ;;
        config) talosctl -n "$NODES" apply-config -f "$src/controlplane-config.yaml" ;;
        etcd)   talosctl -n "$NODES" etcd snapshot restore "$src/etcd-snapshot.db" ;;
        selective)
            PS3="Choisir élément à restaurer : "
            select item in "Configuration" "Manifests" "Secrets" "Annuler"; do
                case $item in
                    Configuration) talosctl -n "$NODES" apply-config -f "$src/controlplane-config.yaml" ;;
                    Manifests)     kubectl apply -f "$src/k8s-resources.yaml" ;;
                    Secrets)       kubectl apply -f "$src/secrets.yaml" ;;
                    Annuler)       log "Abandon"; exit 0 ;;
                esac
                break
            done
            ;;
        *) error "Mode inconnu : $mode" ;;
    esac
    log "✅ Restauration terminée"
}

# ---------- Utilitaires ----------
list_backups() {
    log "📋 Backups disponibles :"
    [[ ! -d $BACKUP_ROOT ]] && { warn "Aucun backup trouvé"; return; }
    for d in "$BACKUP_ROOT"/*; do
        [[ -d $d ]] && echo -e "${GREEN}$(basename $d)${NC} - $(cat $d/comment.txt 2>/dev/null || echo "Sans commentaire") ($(du -sh $d|cut -f1))"
    done
}

cleanup_old_backups() {
    log "🧹 Nettoyage…"
    local keep=($(ls -t "$BACKUP_ROOT"/*/ 2>/dev/null|head -10))
    local cnt=0
    for b in "$BACKUP_ROOT"/*/; do
        [[ ! " ${keep[@]} " =~ " $b " ]] && { rm -rf "$b"; ((cnt++)); }
    done
    log "🗑️  $cnt anciens backups supprimés"
}

# ---------- CLI ----------
usage() {
cat <<EOF
Usage : $0 <backup|restore|list|cleanup> [options]

backup  [-c commentaire] [-t full|config|etcd|manifests]
restore [-f dossier_backup] [-m full|config|etcd|selective]
list
cleanup
EOF
}

[[ $# -eq 0 ]] && { usage; exit 1; }

case "$1" in
    backup)
        shift; c="" t="full"
        while [[ $# -gt 0 ]]; do case $1 in
            -c|--comment) c="$2"; shift 2 ;;
            -t|--type)    t="$2"; shift 2 ;;
            *) shift ;;
        esac; done
        backup_talos "$c" "$t"
        ;;
    restore)
        shift; local f="" m="full"
        while [[ $# -gt 0 ]]; do case $1 in
            -f|--file) f="$2"; shift 2 ;;
            -m|--mode) m="$2"; shift 2 ;;
            *) shift ;;
        esac; done
        [[ -z $f ]] && { list_backups; read -rp "Timestamp du backup : " f; f="$BACKUP_ROOT/$f"; }
        restore_talos "$f" "$m"
        ;;
    list)    list_backups ;;
    cleanup) cleanup_old_backups ;;
    *) usage ;;
esac