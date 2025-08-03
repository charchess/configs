# /etc/nixos/modules/ceph/default.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-custom;
  
  nodeConfigType = types.submodule {
    options = {
      hostname = mkOption {
        type = types.str;
        description = "Nom d'hôte du nœud";
      };
      
      address = mkOption {
        type = types.str;
        description = "Adresse IP du nœud";
      };
      
      roles = mkOption {
        type = types.listOf (types.enum [ "mon" "mgr" "osd" "mds" "rgw" ]);
        default = [];
        description = "Rôles Ceph de ce nœud";
      };
      
      osds = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Liste des devices pour OSD";
      };
    };
  };

in {
  imports = [
    <sops-nix/modules/sops>
    ./services/mon.nix
    ./services/mgr.nix
    ./services/osd.nix
  ];

  options.services.ceph-custom = {
    enable = mkEnableOption "Ceph cluster personnalisé";
    
    clusterName = mkOption {
      type = types.str;
      default = "ceph";
      description = "Nom du cluster";
    };
    
    publicNetwork = mkOption {
      type = types.str;
      default = "192.168.111.0/24";
      description = "Réseau public Ceph";
    };
    
    clusterNetwork = mkOption {
      type = types.str;
      default = "192.168.111.0/24";
      description = "Réseau cluster Ceph";
    };
    
    nodes = mkOption {
      type = types.attrsOf nodeConfigType;
      default = {};
      description = "Configuration des nœuds du cluster";
    };
    
    thisNode = mkOption {
      type = types.str;
      description = "Nom de ce nœud dans la configuration";
    };
  };

  config = mkIf cfg.enable {
    # Configuration sops pour les secrets Ceph
    sops = {
      age.keyFile = "/etc/nixos/secrets/keys/age-keys.txt";
      
      secrets = {
        "ceph-fsid" = {
          sopsFile = /etc/nixos/secrets/ceph/cluster.yaml;
          key = "fsid";
          owner = "ceph";
          group = "ceph";
          mode = "0400";
        };
        
        "ceph-admin-key" = {
          sopsFile = /etc/nixos/secrets/ceph/cluster.yaml;
          key = "admin_key";
          owner = "ceph";
          group = "ceph";
          mode = "0400";
        };
        
        "ceph-mon-key" = {
          sopsFile = /etc/nixos/secrets/ceph/monitors.yaml;
          key = "mon_key";
          owner = "ceph";
          group = "ceph";
          mode = "0400";
        };

        "ceph-bootstrap-osd-key" = {
          sopsFile = /etc/nixos/secrets/ceph/cluster.yaml;
          key = "bootstrap_osd_key";
          owner = "ceph";
          group = "ceph";
          mode = "0400";
        };
      };
    };

    # Configuration Ceph de base
    services.ceph = {
      enable = true;
      global = {
        # Le FSID sera lu depuis les secrets au runtime
        clusterName = cfg.clusterName;
        publicNetwork = cfg.publicNetwork;
        clusterNetwork = cfg.clusterNetwork;
        
        # Configuration d'authentification
        authClusterRequired = "cephx";
        authServiceRequired = "cephx";
        authClientRequired = "cephx";
        
        # Configuration réseau
        msBindIpv4 = true;
        msBindIpv6 = false;
      };
    };

    # Utilisateurs et groupes
    users.users.ceph = {
      isSystemUser = true;
      group = "ceph";
      home = "/var/lib/ceph";
      createHome = true;
    };
    
    users.groups.ceph = {};

    # Configuration réseau
    networking.firewall = {
      allowedTCPPorts = [ 
        6789  # Monitor
        8080  # Manager dashboard  
      ] ++ (range 6800 6900); # OSDs
      
      allowedTCPPortRanges = [
        { from = 6800; to = 7100; }
      ];
    };

    # Packages requis
    environment.systemPackages = with pkgs; [
      ceph
      ceph-client
    ];

    # Répertoires nécessaires
    systemd.tmpfiles.rules = [
      "d /var/lib/ceph 755 ceph ceph -"
      "d /var/lib/ceph/mon 755 ceph ceph -"
      "d /var/lib/ceph/mgr 755 ceph ceph -"
      "d /var/lib/ceph/osd 755 ceph ceph -"
      "d /var/lib/ceph/bootstrap-osd 755 ceph ceph -"
      "d /var/log/ceph 755 ceph ceph -"
    ];
  };
}

