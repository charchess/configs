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
    initialMonitors = [
      { hostname = "jade"; ipAddress = "192.168.111.63"; }
      { hostname = "ruby"; ipAddress = "192.168.111.66"; }
      { hostname = "emy";  ipAddress = "192.168.111.65"; }
    ];
    osdBindAddr = "192.168.111.65";
    osdAdvertisedPublicAddr = "192.168.111.65";

    monitor = {
      enable = true;
      nodeName = "emy";
      bindAddr = "192.168.111.65";
      advertisedPublicAddr = "192.168.111.65";
      initialKeyring = ../../secrets/ceph.mon.keyring;
    };

    manager = {
      enable = true;
      nodeName = "emy";
    };

    mds.enable     = false;
    rgw.enable     = false;

    osds.emy_osd = {
      enable = true;
      id     = 1;
      uuid   = "f6864a0b-86e9-4956-a192-d789dd6c5195";
      blockDevice = "/dev/sda";
      blockDeviceUdevRuleMatcher = ''KERNEL=="sda"'';
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