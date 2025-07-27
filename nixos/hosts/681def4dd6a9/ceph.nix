{ config, pkgs, lib, ... }:

{
  networking.firewall.allowedTCPPorts = [ 6789 ];
  networking.firewall.allowedTCPPortRanges = [ { from = 6800; to = 7300; } ];

  services.ceph-benaco = {
    enable = true;
    clusterName = "ceph";
    fsid = "4b687c5c-5a20-4a77-8774-487989fd0bc7";
    publicNetworks = [ "192.168.111.0/24" ];
    adminKeyring = ../../secrets/ceph.client.admin.keyring;
    initialMonitors = [ { hostname = "jade"; ipAddress = "192.168.111.63"; } ];
    osdBindAddr = "192.168.111.65";
    osdAdvertisedPublicAddr = "192.168.111.65";

    monitor.enable = false;
    manager.enable = false;
    mds.enable     = false;
    rgw.enable     = false;

    osds.emy_osd = {
      enable = true;
      id     = 1;
      uuid   = "6d1fbe6b-7cc4-443b-b699-ac85810ad3ac";
      blockDevice = "/dev/sdb";
      blockDeviceUdevRuleMatcher = ''KERNEL=="sdb"'';
      bootstrapKeyring = ../../secrets/ceph.client.bootstrap-osd.keyring;
      skipZap = false;
    };
  };

  systemd.services.ceph-osd-1 = {
    description = "Ceph OSD 1 (emy)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = "ceph";
      Group     = "ceph";
      ExecStart = "${pkgs.ceph}/bin/ceph-osd -f --cluster ceph --id 1";
      Restart   = "always";
      RestartSec = 5;
    };
  };
}