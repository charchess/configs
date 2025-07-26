{ config, pkgs, lib, ... }:

{
  services.ceph-benaco = {
    enable = true;
    clusterName = "ceph";
    fsid = "4b687c5c-5a20-4a77-8774-487989fd0bc7";
    publicNetworks = [ "192.168.111.0/24" ];
    adminKeyring = ../../secrets/ceph.client.admin.keyring;
    initialMonitors = [ { hostname = "jade"; ipAddress = "192.168.111.63"; } ];
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
        port = 8080;
    };

    osds.jade_osd = {
        enable = true;
        id = 0;
        uuid = "5d3d44a2-9ab8-4c24-a7f1-aa01dfe66778";
        blockDevice = "/dev/sdb";
        blockDeviceUdevRuleMatcher = ''KERNEL=="sdb"'';
        bootstrapKeyring = ../../secrets/ceph.client.bootstrap-osd.keyring;
        skipZap = false;
    };
  };
}