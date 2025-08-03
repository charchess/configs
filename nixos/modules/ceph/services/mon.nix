{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-custom;
  thisNodeCfg = cfg.nodes.${cfg.thisNode};
  
  isMonNode = elem "mon" thisNodeCfg.roles;

in {
  config = mkIf (cfg.enable && isMonNode) {
    # Activation du service monitor Ceph intégré à NixOS
    services.ceph.mon = {
      enable = true;
      daemons = [ cfg.thisNode ];
    };

    # Service de gestion des clés avec sops
    systemd.services.ceph-keys-manager = {
      description = "Ceph Keys Manager avec sops";
      after = [ "network.target" ];
      before = [ "ceph-mon-bootstrap.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Group = "root";
      };
      
      script = ''
        export SOPS_AGE_KEY_FILE="/etc/nixos/secrets/keys/age-keys.txt"
        
        # Vérification si les clés existent dans sops
        if sops -d /etc/nixos/secrets/ceph/cluster.yaml > /tmp/cluster-keys.yaml 2>/dev/null; then
          echo "📋 Utilisation des clés existantes depuis sops"
          
          # Extraction des clés depuis sops
          ADMIN_KEY=$(grep "admin_key:" /tmp/cluster-keys.yaml | cut -d' ' -f2)
          MON_KEY=$(sops -d /etc/nixos/secrets/ceph/monitors.yaml | grep "mon_key:" | cut -d' ' -f2)
          BOOTSTRAP_OSD_KEY=$(grep "bootstrap_osd_key:" /tmp/cluster-keys.yaml | cut -d' ' -f2)
          
          rm -f /tmp/cluster-keys.yaml
        else
          echo "🔑 Génération de nouvelles clés et sauvegarde dans sops"
          
          # Génération de nouvelles clés
          ADMIN_KEY=$(${pkgs.ceph}/bin/ceph-authtool --gen-print-key)
          MON_KEY=$(${pkgs.ceph}/bin/ceph-authtool --gen-print-key)
          BOOTSTRAP_OSD_KEY=$(${pkgs.ceph}/bin/ceph-authtool --gen-print-key)
          
          # Sauvegarde dans sops (mise à jour des fichiers existants)
          # Cette partie nécessiterait un script plus complexe pour modifier les fichiers sops
          echo "⚠️  Nouvelles clés générées - à sauvegarder manuellement dans sops"
        fi
        
        # Création des keyrings déclaratifs
        mkdir -p /etc/ceph
        
        # Keyring admin
        cat > /etc/ceph/ceph.client.admin.keyring << EOF
        [client.admin]
        key = $ADMIN_KEY
        caps mds = "allow *"
        caps mgr = "allow *" 
        caps mon = "allow *"
        caps osd = "allow *"
        EOF
        
        # Keyring bootstrap OSD
        mkdir -p /var/lib/ceph/bootstrap-osd
        cat > /var/lib/ceph/bootstrap-osd/ceph.keyring << EOF
        [client.bootstrap-osd]
        key = $BOOTSTRAP_OSD_KEY
        caps mon = "profile bootstrap-osd"
        caps mgr = "allow r"
        EOF
        
        # Keyring monitor temporaire
        cat > /var/lib/ceph/mon.keyring << EOF
        [mon.]
        key = $MON_KEY
        caps mon = "allow *"
        EOF
        
        # Permissions
        chown ceph:ceph /etc/ceph/ceph.client.admin.keyring
        chown -R ceph:ceph /var/lib/ceph/bootstrap-osd/
        chown ceph:ceph /var/lib/ceph/mon.keyring
        chmod 600 /etc/ceph/ceph.client.admin.keyring
        chmod 600 /var/lib/ceph/bootstrap-osd/ceph.keyring
        chmod 600 /var/lib/ceph/mon.keyring
        
        echo "🔑 Keyrings configurés de façon déclarative"
      '';
    };

    # Service de bootstrap du monitor
    systemd.services.ceph-mon-bootstrap = {
      description = "Bootstrap Ceph Monitor ${cfg.thisNode}";
      after = [ "network.target" "ceph-keys-manager.service" ];
      before = [ "ceph-mon-${cfg.thisNode}.service" ];
      wants = [ "ceph-keys-manager.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Group = "root";
      };
      
      script = ''
        MON_DATA="/var/lib/ceph/mon/${cfg.clusterName}-${cfg.thisNode}"
        
        if [ ! -f "$MON_DATA/done" ]; then
          echo "🚀 Bootstrap du monitor ${cfg.thisNode} sur ${thisNodeCfg.address}"
          
          # Génération de la monmap avec la bonne IP
          ${pkgs.ceph}/bin/monmaptool --create --clobber \
            --add ${cfg.thisNode} ${thisNodeCfg.address}:6789 \
            --fsid ${cfg.fsid} /var/lib/ceph/monmap
          
          # Préparation du répertoire monitor
          mkdir -p "$MON_DATA"
          
          # Initialisation du monitor avec le keyring existant
          ${pkgs.ceph}/bin/ceph-mon --mkfs -i ${cfg.thisNode} \
            --monmap /var/lib/ceph/monmap --keyring /var/lib/ceph/mon.keyring
          
          # Permissions correctes
          chown -R ceph:ceph "$MON_DATA"
          touch "$MON_DATA/done"
          
          # Nettoyage
          rm -f /var/lib/ceph/monmap /var/lib/ceph/mon.keyring
          
          echo "✅ Monitor ${cfg.thisNode} initialisé sur ${thisNodeCfg.address}:6789"
        else
          echo "ℹ️  Monitor ${cfg.thisNode} déjà initialisé"
        fi
      '';
    };
  };
}
