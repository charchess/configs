{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-custom;
  thisNodeCfg = cfg.nodes.${cfg.thisNode};
  
  isMgrNode = elem "mgr" thisNodeCfg.roles;

in {
  config = mkIf (cfg.enable && isMgrNode) {
    # Activation du service manager Ceph intégré à NixOS
    services.ceph.mgr = {
      enable = true;
      daemons = [ cfg.thisNode ];
    };

    # Service de bootstrap du manager
    systemd.services.ceph-mgr-bootstrap = {
      description = "Bootstrap Ceph Manager ${cfg.thisNode}";
      after = [ "network.target" "ceph-mon-jade.service" ];
      before = [ "ceph-mgr-${cfg.thisNode}.service" ];
      wants = [ "ceph-mon-jade.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Group = "root";
      };
      
      script = ''
        MGR_DATA="/var/lib/ceph/mgr/${cfg.clusterName}-${cfg.thisNode}"
        
        if [ ! -f "$MGR_DATA/done" ]; then
          echo "Bootstrap du manager ${cfg.thisNode}..."
          
          # Attendre que le monitor soit prêt
          sleep 5
          
          # Création du répertoire manager
          mkdir -p "$MGR_DATA"
          
          # Génération de la clé manager
          ${pkgs.ceph}/bin/ceph-authtool --create-keyring "$MGR_DATA/keyring" \
            --gen-key -n mgr.${cfg.thisNode} \
            --cap mon 'allow profile mgr' \
            --cap osd 'allow *' \
            --cap mds 'allow *'
          
          chown -R ceph:ceph "$MGR_DATA"
          touch "$MGR_DATA/done"
          
          echo "Manager ${cfg.thisNode} initialisé avec succès"
        else
          echo "Manager ${cfg.thisNode} déjà initialisé"
        fi
      '';
    };
  };
}
