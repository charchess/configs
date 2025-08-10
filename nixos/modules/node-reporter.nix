# /etc/nixos/node-api-reporter.nix
#
# Version de base utilisant environment.etc.
# - Syntaxe corrigée (`mode = "0755"`)
# - Dépendances garanties via `environment.systemPackages`

{ lib, config, pkgs, ... }:

let
  listenPort = 9101;
in
{
  config = {
    # On ajoute les dépendances du script aux paquets du système.
    # C'est la garantie qu'ils ne seront jamais supprimés par le nettoyeur.
    environment.systemPackages = with pkgs; [
      socat util-linux coreutils jq gawk
    ];
    
    # On ouvre le port dans le pare-feu.
    networking.firewall.allowedTCPPorts = [ listenPort ];

    # Le script est créé dans /etc.
    environment.etc."node-status-script.sh" = {
      mode = "0755";
      text = ''
        #!${pkgs.stdenv.shell}
        set -e

        # --- keepalived ---
        KEEPALIVED_FILE="/var/run/keepalived_state"
        if [ -r "$KEEPALIVED_FILE" ]; then
            KEEPALIVED_STATE=$(${pkgs.gawk}/bin/awk '{print $1}' "$KEEPALIVED_FILE")
            KEEPALIVED_PRIO=$(${pkgs.gawk}/bin/awk '{print $2}' "$KEEPALIVED_FILE" 2>/dev/null || echo "100")
            LAST_UPDATE=$(stat -c %Y "$KEEPALIVED_FILE")
        else
            KEEPALIVED_STATE="unknown"
            KEEPALIVED_PRIO=-"unknown"
            LAST_UPDATE="unknown"
        fi
        NOW=$(date +%s)
        AGE=$((NOW - LAST_UPDATE))
 
        # --- NFS ---
        NFS_ACTIVE=true
        for mount in "/data/nfs/content" "/data/nfs/containers" "/data/nfs/downloads"; do
          if ! ${pkgs.util-linux}/bin/findmnt -M "$mount" >/dev/null; then NFS_ACTIVE=false; break; fi
        done
 
        # --- Ceph ---
        IS_CEPH_NODE=false
        if ${pkgs.docker}/bin/docker ps --format '{{.Names}}' | grep -q "osd\."; then
          IS_CEPH_NODE=true
        fi
 
        # --- AVX ---
        AVX_SUPPORT=$(grep -q avx /proc/cpuinfo && echo true || echo false)
    
        # --- Date --- 
        DATE_ISO=$(date -Iseconds)

        # --- JSON ---
        echo "HTTP/1.1 200 OK"
        echo "Content-Type: application/json"
        echo ""
        ${pkgs.jq}/bin/jq -n \
          --arg nfs    "$NFS_ACTIVE" \
          --arg ceph   "$IS_CEPH_NODE" \
          --arg avx    "$AVX_SUPPORT" \
          --arg state  "$KEEPALIVED_STATE" \
          --argjson prio "$KEEPALIVED_PRIO" \
          --argjson age "$AGE" \
          --arg date   "$DATE_ISO" \
          '{
            "disk.feature.nfs": $nfs,
            "disk.feature.ceph": $ceph,
            "cpu.feature.avx": $avx,
            "keepalived.state": $state,
            "keepalived.priority": $prio,
            "keepalived.age_seconds": $age,
            "date": $date,
            "status": "ok"
          }'
      '';
    };

    # Le service systemd qui lance le micro-serveur web.
    systemd.services.node-status-api = {
      description = "Node Status Reporter API";
      after = [ "network.target" "docker.service" ];
#      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        # On appelle socat avec son chemin absolu. Il exécute ensuite le script créé dans /etc.
        ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:${toString listenPort},fork EXEC:/etc/node-status-script.sh";
        Restart = "on-failure";
      };
    };
  };
}