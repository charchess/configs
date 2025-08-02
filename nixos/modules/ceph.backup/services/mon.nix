# /etc/nixos/modules/ceph/services/mon.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-custom;
  thisNodeCfg = cfg.nodes.${cfg.thisNode};
  
  isMonNode = elem "mon" thisNodeCfg.roles;
  
  # Génération de la monmap initiale
  monNodes = filterAttrs (name: node: elem "mon" node.roles) cfg.nodes;
  
  # Script de génération de la configuration Ceph
  cephConfContent = ''
    [global]
    fsid = ${config.sops.placeholder."ceph-fsid"}
    cluster = ${cfg.clusterName}
    public network = ${cfg.publicNetwork}
    cluster network = ${cfg.clusterNetwork}
    auth cluster required = cephx
    auth service required = cephx
    auth client required = cephx
    
    ms bind ipv4 = true
    ms bind ipv6 = false
    
    # Monitor configuration
    mon initial members = ${concatStringsSep "," (attrNames monNodes)}
    mon host = ${concatStringsSep "," (mapAttrsToList (name: node: node.address) monNodes)}
    
    [mon]
    mon data = /var/lib/ceph/mon/${cfg.clusterName}-$id
    mon cluster log file = /var/log/ceph/${cfg.clusterName}-mon-$id.log
  '';

in {
  config = mkIf (cfg.enable && isMonNode) {
    # Service de génération de la configuration Ceph
    systemd.services.ceph-config-generator = {
      description = "Generate Ceph configuration with secrets";
      wantedBy = [ "multi-user.target" ];
      after = [ "sops-nix.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
      };
      
      script = ''
        # Attendre que les secrets soient disponibles
        while [ ! -f ${config.sops.secrets."ceph-fsid".path} ]; do
          echo "Attente des secrets sops..."
          sleep 1
        done
        
        # Lecture du FSID depuis le secret
        FSID=$(cat ${config.sops.secrets."ceph-fsid".path})
        
        # Génération de la configuration Ceph
        mkdir -p /etc/ceph
        cat > /etc/ceph/ceph.conf << EOF
        [global]
        fsid = $FSID
        cluster = ${cfg.clusterName}
        public network = ${cfg.publicNetwork}
        cluster network = ${cfg.clusterNetwork}
        auth cluster required = cephx
        auth service required = cephx
        auth client required = cephx
        
        ms bind ipv4 = true
        ms bind ipv6 = false
        
        # Monitor configuration
        mon initial members = ${concatStringsSep "," (attrNames monNodes)}
        mon host = ${concatStringsSep "," (mapAttrsToList (name: node: node.address) monNodes)}
        
        [mon]
        mon data = /var/lib/ceph/mon/${cfg.clusterName}-\$id
        mon cluster log file = /var/log/ceph/${cfg.clusterName}-mon-\$id.log
        EOF
        
        chown ceph:ceph /etc/ceph/ceph.conf
        chmod 644 /etc/ceph/ceph.conf
      '';
    };

    # Service de bootstrap du monitor
    systemd.services.ceph-mon-bootstrap = {
      description = "Bootstrap Ceph Monitor ${cfg.thisNode}";
      after = [ "network.target" "ceph-config-generator.service" "sops-nix.service" ];
      wants = [ "ceph-config-generator.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "ceph";
        Group = "ceph";
      };
      
      script = ''
        MON_DATA="/var/lib/ceph/mon/${cfg.clusterName}-${cfg.thisNode}"
        FSID=$(cat ${config.sops.secrets."ceph-fsid".path})
        
        if [ ! -f "$MON_DATA/done" ]; then
          echo "Bootstrap du monitor ${cfg.thisNode}..."
          
          # Création du keyring monitor avec la clé des secrets
          MON_KEY=$(cat ${config.sops.secrets."ceph-mon-key".path})
          
          cat > /tmp/mon.keyring << EOF
        [mon.]
        key = $MON_KEY
        caps mon = "allow *"
        EOF
          
          # Génération de la monmap initiale
          ${pkgs.ceph}/bin/monmaptool --create --clobber \
            ${concatStringsSep " " (mapAttrsToList (name: node: "--add ${name} ${node.address}:6789") monNodes)} \
            --fsid $FSID /tmp/monmap
          
          # Préparation du répertoire monitor
          mkdir -p "$MON_DATA"
          chown ceph:ceph "$MON_DATA"
          
          # Initialisation du monitor
          ${pkgs.ceph}/bin/ceph-mon --mkfs -i ${cfg.thisNode} \
            --monmap /tmp/monmap --keyring /tmp/mon.keyring
          
          chown -R ceph:ceph "$MON_DATA"
          touch "$MON_DATA/done"
          
          # Nettoyage
          rm -f /tmp/mon.keyring /tmp/monmap
          
          echo "Monitor ${cfg.thisNode} initialisé"
        fi
      '';
    };

    # Service monitor principal
    systemd.services.ceph-mon = {
      description = "Ceph Monitor ${cfg.thisNode}";
      after = [ "network.target" "ceph-mon-bootstrap.service" ];
      wants = [ "ceph-mon-bootstrap.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "ceph";
        Group = "ceph";
        ExecStart = "${pkgs.ceph}/bin/ceph-mon -f -i ${cfg.thisNode}";
        Restart = "on-failure";
        RestartSec = "10s";
      };
      
      preStart = ''
        # Vérification que le bootstrap est terminé
        if [ ! -f "/var/lib/ceph/mon/${cfg.clusterName}-${cfg.thisNode}/done" ]; then
          echo "Monitor non initialisé, abandon..."
          exit 1
        fi
      '';
    };
  };
}

