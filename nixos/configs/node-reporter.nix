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
      socat util-linux docker coreutils jq
    ];
    
    # On ouvre le port dans le pare-feu.
    networking.firewall.allowedTCPPorts = [ listenPort ];

    # Le script est créé dans /etc.
    environment.etc."node-status-script.sh" = {
      # --- CORRECTION DE SYNTAXE ---
      # On utilise 'mode' pour rendre le script exécutable.
      mode = "0755";
      
      # Le script utilise des chemins absolus pour une robustesse maximale.
      text = ''
        #!${pkgs.stdenv.shell}
        set -e
        # Détection NFS
        NFS_ACTIVE=true
        for mount in "/data/nfs/content" "/data/nfs/containers" "/data/nfs/downloads"; do
          if ! ${pkgs.util-linux}/bin/findmnt -M "$mount" >/dev/null; then NFS_ACTIVE=false; break; fi
        done
        # Détection Ceph
        IS_CEPH_NODE=false
        if ${pkgs.docker}/bin/docker ps --format '{{.Names}}' | grep -q "osd\."; then
          IS_CEPH_NODE=true
        fi
        # Détection AVX
        AVX_SUPPORT=$(grep -q avx /proc/cpuinfo && echo true || echo false)
        # Réponse HTTP
        echo "HTTP/1.1 200 OK"
        echo "Content-Type: application/json"
        echo ""
        ${pkgs.jq}/bin/jq -n --arg nfs "$NFS_ACTIVE" --arg ceph "$IS_CEPH_NODE" --arg avx "$AVX_SUPPORT" \
          '{"disk.feature.nfs": $nfs, "disk.feature.ceph": $ceph, "cpu.feature.avx": $avx}'
      '';
    };

    # Le service systemd qui lance le micro-serveur web.
    systemd.services.node-status-api = {
      description = "Node Status Reporter API";
      after = [ "network.target" "docker.service" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        # On appelle socat avec son chemin absolu. Il exécute ensuite le script créé dans /etc.
        ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:${toString listenPort},fork EXEC:/etc/node-status-script.sh";
        Restart = "on-failure";
      };
    };
  };
}