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
    osdBindAddr = "192.168.111.66";
    osdAdvertisedPublicAddr = "192.168.111.66";

    monitor.enable = false;
    manager.enable = false;
    mds.enable     = false;
    rgw.enable     = false;

    osds.ruby_osd = {
      enable = true;
      id     = 2;
      uuid   = "e5205f83-0540-459b-90d6-58d78b7fa510";
      blockDevice = "/dev/sdc";
      blockDeviceUdevRuleMatcher = ''KERNEL=="sdc"'';
      bootstrapKeyring = ../../secrets/ceph.client.bootstrap-osd.keyring;
      skipZap = false;
    };
  };

  systemd.services.ceph-osd-2 = {
    description = "Ceph OSD 2 (ruby)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = "ceph";
      Group     = "ceph";
      ExecStart = "${pkgs.ceph}/bin/ceph-osd -f --cluster ceph --id 2";
      Restart   = "always";
      RestartSec = 5;
    };
  };
}