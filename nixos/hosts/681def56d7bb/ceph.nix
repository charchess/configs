{ config, pkgs, lib, ... }:

let
  # Définir les paramètres du cluster Ceph une seule fois
  cephFsid = "3541d2bd-2c7e-411c-8f9a-c1a06d79e2c4";
  cephMonName = "jade";
  cephMonIp = "192.168.111.63"; # Assumer que ce noeud est 'jade'

  # Générer les keyrings Ceph en tant que package Nix
  cephKeyrings = pkgs.callPackage ../../modules/pkgs/ceph-keyrings.nix {
    fsid    = cephFsid;
    monName = cephMonName;
    monIp   = cephMonIp;
  };

in
{
  imports = [
    # Le module ceph-benaco existant (ne pas toucher)
    ../../modules/ceph-benaco.nix
    # Le nouveau module pour déployer les keyrings générés
    ../../modules/ceph-keyring-config.nix
  ];

  networking.firewall.allowedTCPPorts = [ 3030 ];

  # Activer et configurer le déploiement des keyrings
  services.cephKeyringConfig = {
    enable = true;
    cephKeyringsPackage = cephKeyrings;
  };

  services.ceph-benaco = {
    enable = true;
    clusterName = "ceph";
    fsid = cephFsid; # Utiliser l'FSID défini ci-dessus
    publicNetworks = [ "192.168.111.0/24" ];
    # Référencer les keyrings déployés dans /etc/ceph/
    adminKeyring = "/etc/ceph/ceph.client.admin.keyring";
    initialMonitors = [
      { hostname = "jade"; ipAddress = "192.168.111.63"; }
#      { hostname = "ruby"; ipAddress = "192.168.111.66"; }
#      { hostname = "emy";  ipAddress = "192.168.111.65"; }
    ];
    osdBindAddr          = "192.168.111.63";
    osdAdvertisedPublicAddr = "192.168.111.63";

    monitor = {
      enable = true;
      nodeName = cephMonName;
      bindAddr = cephMonIp;
      advertisedPublicAddr = cephMonIp;
      initialKeyring = "/etc/ceph/ceph.mon.keyring"; # Référencer le keyring déployé
    };

    manager = {
      enable = true;
      nodeName = "jade";
    };

    mds = {
      enable = true;
      nodeName = "jade";
      listenAddr = "192.168.111.63";
    };

    rgw = {
      enable = true;
      nodeName = "jade";
      listenAddr = "192.168.111.63";
      port = 3030;
    };

    osds.jade_osd = {
      enable = true;
      id = 15;
      uuid = "51e372e3-f4e6-42c7-9773-1b32df43dd80";
      blockDevice = "/dev/sdb";
      blockDeviceUdevRuleMatcher = ''KERNEL=="sdb"'';
      bootstrapKeyring = "/etc/ceph/ceph.client.bootstrap-osd.keyring"; # Référencer le keyring déployé
      skipZap = false;
    };
  };

  # Supprimer le service OSD manuel redondant
  # systemd.services.ceph-osd-0 = { ... }; # Suppression

  # Consolider et corriger la configuration du montage CephFS
  # Utiliser systemd.mounts pour un meilleur contrôle des dépendances.
#  systemd.mounts = [{
#    where  = "/data/cephfs";
#    what   = "192.168.111.63:6789:/"; # Adresse d'un moniteur pour le montage
#    type   = "ceph";
#    # Utiliser la clé brute client.admin générée
#    options = "name=admin,secretfile=/etc/ceph/ceph.client.admin.secret_key,_netdev";
#    wantedBy = [ "multi-user.target" ];
#    # S'assurer que les services Ceph sont démarrés avant le montage
#    after = [ "network.target" "ceph-mon.service" "ceph-mds.service" ];
#    requires = [ "network.target" "ceph-mon.service" "ceph-mds.service" ];
#  }];

  # L'automount est une bonne pratique pour les partages réseau
#  systemd.automounts = [{
#    where  = "/data/cephfs";
#    wantedBy = [ "multi-user.target" ];
#  }];
}