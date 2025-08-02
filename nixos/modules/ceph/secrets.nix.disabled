# /etc/nixos/modules/ceph/secrets.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-custom;
in {
  options.services.ceph-custom.secrets = {
    enable = mkEnableOption "Gestion des secrets Ceph avec sops";
    
    secretsPath = mkOption {
      type = types.str;
      default = "/etc/nixos/secrets/ceph";
      description = "Chemin vers les fichiers de secrets Ceph";
    };
  };

  config = mkIf (cfg.enable && cfg.secrets.enable) {
    # Import de sops-nix
    imports = [ <sops-nix/modules/sops> ];

    # Configuration sops
    sops = {
      defaultSopsFile = "${cfg.secrets.secretsPath}/cluster.yaml";
      validateSopsFiles = false; # Désactivé pour éviter les problèmes de validation
      
      # Emplacement de la clé age
      age = {
        keyFile = "/var/lib/sops-nix/key.txt";
        generateKey = true;
      };

      # Secrets cluster
      secrets = {
        "ceph-fsid" = {
          sopsFile = "${cfg.secrets.secretsPath}/cluster.yaml";
          key = "fsid";
          owner = "ceph";
          group = "ceph";
          mode = "0400";
        };
        
        "ceph-admin-key" = {
          sopsFile = "${cfg.secrets.secretsPath}/cluster.yaml";
          key = "admin_key";
          owner = "ceph";
          group = "ceph";
          mode = "0400";
        };
        
        "ceph-bootstrap-osd-key" = {
          sopsFile = "${cfg.secrets.secretsPath}/cluster.yaml";
          key = "bootstrap_osd_key";
          owner = "ceph";
          group = "ceph";
          mode = "0400";
        };

        # Secrets monitors
        "ceph-mon-key" = {
          sopsFile = "${cfg.secrets.secretsPath}/monitors.yaml";
          key = "mon_key";
          owner = "ceph";
          group = "ceph";
          mode = "0400";
        };
      };
    };

    # Fonctions utilitaires pour lire les secrets
    services.ceph-custom.lib = {
      # Fonction pour obtenir le FSID depuis le secret
      getFsid = config.sops.secrets."ceph-fsid".path;
      
      # Fonction pour obtenir la clé admin
      getAdminKey = config.sops.secrets."ceph-admin-key".path;
      
      # Fonction pour obtenir la clé monitor
      getMonKey = config.sops.secrets."ceph-mon-key".path;
    };

    # Assurer que l'utilisateur ceph existe
    users.users.ceph = {
      isSystemUser = true;
      group = "ceph";
      home = "/var/lib/ceph";
      createHome = true;
    };
    
    users.groups.ceph = {};
  };
}


