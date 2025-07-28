{ config, pkgs, lib, ... }:

{
  networking.firewall.allowedTCPPorts = [ 3030 ];

  services.ceph-benaco = {
    enable = true;
    clusterName = "ceph";
    fsid = "3541d2bd-2c7e-411c-8f9a-c1a06d79e2c4";
    publicNetworks = [ "192.168.111.0/24" ];
    adminKeyring = ../../secrets/ceph.client.admin.keyring;
    initialMonitors = [
      { hostname = "jade"; ipAddress = "192.168.111.63"; }
      { hostname = "ruby"; ipAddress = "192.168.111.66"; }
      { hostname = "emy";  ipAddress = "192.168.111.65"; }
    ];
    osdBindAddr          = "192.168.111.63";
    osdAdvertisedPublicAddr = "192.168.111.63";

    monitor = {
      enable = true;
      nodeName = "jade";
      bindAddr = "192.168.111.63";
      advertisedPublicAddr = "192.168.111.63";
      initialKeyring = ../../secrets/ceph.mon.keyring;
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
      id = 0;
      uuid = "ac2868e4-f35d-45a1-8400-9154402a0c56";
      blockDevice = "/dev/sdb";
      blockDeviceUdevRuleMatcher = ''KERNEL=="sdb"'';
      bootstrapKeyring = ../../secrets/ceph.client.bootstrap-osd.keyring;
      skipZap = false;
    };
  };

  fileSystems."/data/cephfs" = {
    device  = "192.168.111.63:6789:/";
    fsType  = "ceph";
    options = [
      "name=admin"
      "secretfile=/etc/ceph/cephfs-admin.key"
      "_netdev"
    ];
  };

  systemd.services.ceph-osd-0 = {
    description = "Ceph OSD 0";
    wantedBy = [ "multi-user.target" ];  
    serviceConfig = {
      Type = "simple";
      User = "ceph";
      Group = "ceph";
      ExecStart = "${pkgs.ceph}/bin/ceph-osd -f --cluster ceph --id 0";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.mounts = [{
    where  = "/data/cephfs";
    what   = "192.168.111.63:6789:/";
    type   = "ceph";
    options = "name=admin,secretfile=/etc/ceph/ceph.client.admin.secret_key,_netdev";
    wantedBy = [ "multi-user.target" ];
  }];

  systemd.automounts = [{
    where  = "/data/cephfs";
    wantedBy = [ "multi-user.target" ];
  }];
}