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
    ./services/mon.nix
    ./services/mgr.nix
    ./services/osd.nix
  ];

  options.services.ceph-custom = {
    enable = mkEnableOption "Ceph cluster personnalisé";
    
    fsid = mkOption {
      type = types.str;
      default = "cfe4f2e3-4664-42ba-9b84-6c44b8943479";
      description = "FSID du cluster Ceph";
    };
    
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

    # Nouvelle option pour le déploiement initial
    bootstrapSingleNode = mkOption {
      type = types.bool;
      default = true;
      description = "Permet au premier monitor de démarrer seul";
    };
  };

  config = mkIf cfg.enable {
    # Configuration Ceph adaptée pour le déploiement initial
    services.ceph = {
      enable = true;
      
      # Configuration globale
      global = {
        fsid = cfg.fsid;
        clusterName = cfg.clusterName;
        publicNetwork = cfg.publicNetwork;
        clusterNetwork = cfg.clusterNetwork;
        
        # Configuration d'authentification
        authClusterRequired = "cephx";
        authServiceRequired = "cephx";
        authClientRequired = "cephx";
        
        # Configuration des monitors - adaptée pour le bootstrap
        monInitialMembers = if cfg.bootstrapSingleNode 
          then cfg.thisNode  # Un seul monitor pour le bootstrap
          else let
            monNodes = filterAttrs (name: node: elem "mon" node.roles) cfg.nodes;
          in concatStringsSep ", " (attrNames monNodes);
        
        monHost = if cfg.bootstrapSingleNode 
          then cfg.nodes.${cfg.thisNode}.address  # Une seule IP pour le bootstrap
          else let
            monNodes = filterAttrs (name: node: elem "mon" node.roles) cfg.nodes;
          in concatStringsSep ", " (mapAttrsToList (name: node: node.address) monNodes);
      };
      
      # Configuration supplémentaire pour forcer le bon réseau
      extraConfig = {
        "ms bind ipv4" = "true";
        "ms bind ipv6" = "false";
        # Forcer l'utilisation du réseau 111
        "public addr" = "${cfg.nodes.${cfg.thisNode}.address}";
        "cluster addr" = "${cfg.nodes.${cfg.thisNode}.address}";
        
        # Configuration pour permettre le démarrage d'un monitor unique
        "mon allow pool delete" = "true";
        "mon cluster log file" = "/var/log/ceph/ceph-mon.log";
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
      sops
      nix
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
