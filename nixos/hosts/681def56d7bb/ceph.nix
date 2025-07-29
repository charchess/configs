{ config, pkgs, lib, ... }:

let
  cephFsid = "3541d2bd-2c7e-411c-8f9a-c1a06d79e2c4";
  cephMonName = "jade";
  cephMonIp = "192.168.111.63";

  # cephKeyrings now returns an attrset of paths
  cephKeyrings = pkgs.callPackage ../../modules/pkgs/ceph-keyrings.nix {
    fsid    = cephFsid;
    monName = cephMonName;
    monIp   = cephMonIp;
    # On Jade, we don't pass initialAdminKey or initialBootstrapOsdKey; they will be generated.
  };

in
{
  imports = [
    ../../modules/ceph-benaco.nix
    ../../modules/ceph-keyring-config.nix
  ];

  # IMPORTANT: Ensure Ceph monitor ports are open!
  networking.firewall.allowedTCPPorts = [ 3030 6789 ];

  services.cephKeyringConfig = {
    enable = true;
    cephKeyrings = cephKeyrings; # Pass the *attribute set* here
  };

  services.ceph-benaco = {
    enable = true;
    clusterName = "ceph";
    fsid = cephFsid;
    publicNetworks = [ "192.168.111.0/24" ];
    # Référence les chemins spécifiques depuis l'attrset renvoyé par cephKeyrings
    adminKeyring = cephKeyrings.adminKeyring;
    initialMonitors = [
      { hostname = "jade"; ipAddress = "192.168.111.63"; }
      { hostname = "ruby"; ipAddress = "192.168.111.66"; }
      { hostname = "emy";  ipAddress = "192.168.111.65"; }
    ];
    osdBindAddr          = "192.168.111.63";
    osdAdvertisedPublicAddr = "192.168.111.63";

    monitor = {
      enable = true;
      nodeName = cephMonName;
      bindAddr = cephMonIp;
      advertisedPublicAddr = cephMonIp;
      initialKeyring = cephKeyrings.monKeyring;
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

    osds = {
      jade_osd = {
        enable = true;
        id = 15;
        uuid = "51e372e3-f4e6-42c7-9773-1b32df43dd80";
        blockDevice = "/dev/sdb";
        blockDeviceUdevRuleMatcher = ''KERNEL=="sdb"'';
        bootstrapKeyring = cephKeyrings.bootstrapOsdKeyring;
        skipZap = false;
      };
    };
  };
}
