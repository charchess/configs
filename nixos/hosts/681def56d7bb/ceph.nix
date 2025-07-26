{ config, pkgs, lib, ... }:

{
  imports = [ ../../modules/ceph-benaco.nix ];

  services.ceph-benaco = {
    enable = true;

    # Identité du cluster
    fsid        = "4b687c5c-5a20-4a77-8774-487989fd0bc7";
    clusterName = "ceph";

    # Réseau public
    publicNetworks = [ "192.168.111.0/24" ];

    # Moniteur initial (unique ici)
    initialMonitors = [
      { hostname = "jade"; ipAddress = "192.168.111.63"; }
    ];

    # Chemin vers le keyring admin
    adminKeyring = "/etc/ceph/ceph.client.admin.keyring";

    # OSD unique : récupération des données existantes → skipZap = true
    osds = {
      jade_osd = {
        enable      = true;
        id          = 0;                                   # à adapter si votre OSD n’est pas le 0
        uuid        = "4b687c5c-5a20-4a77-8774-487989fd0bc7"; # même fsid ici, changez si l’OSD a un UUID différent
        blockDevice = "/dev/sdb";                          # à adapter (/dev/sda, /dev/nvme0n1, etc.)
        blockDeviceUdevRuleMatcher = ''KERNEL=="sdb"'';
        bootstrapKeyring = "/etc/ceph/ceph.client.bootstrap-osd.keyring";
        skipZap     = true;   # ← on ne zapera pas le disque
      };
    };

    # On déclare aussi un monitor, un manager et un MDS sur cette machine
    monitor = {
      enable               = true;
      nodeName             = "jade";
      bindAddr             = "192.168.111.63";
      advertisedPublicAddr = "192.168.111.63";
      initialKeyring       = "/etc/ceph/ceph.mon.keyring";
    };

    manager = {
      enable   = true;
      nodeName = "jade";
    };

    mds = {
      enable    = true;
      nodeName  = "jade";
      listenAddr = "192.168.111.63";
    };

    extraConfig = ''
      # Options supplémentaires si besoin
    '';
  };
}


