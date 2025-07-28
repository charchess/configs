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
    osdBindAddr = "192.168.111.66";
    osdAdvertisedPublicAddr = "192.168.111.66";
    monitor = {
      enable = true;
      nodeName = "ruby";
      bindAddr = "192.168.111.66";
      advertisedPublicAddr = "192.168.111.66";
      initialKeyring = ../../secrets/ceph.mon.keyring;
    };

    manager = {
      enable = true;
      nodeName = "ruby";
    };

    mds = {
      enable = true;
      nodeName = "ruby";
      listenAddr = "192.168.111.66";
    };

    rgw = {
      enable = true;
      nodeName = "ruby";
      listenAddr = "192.168.111.66";
      port = 3030;
    };

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

  systemd.services.ceph-mon-init-ruby = {
    description = "Ensure Ceph monitor ruby is initialized (idempotent)";
    wantedBy = [ "multi-user.target" ];
    before = [ "ceph-mon@ruby.service" ];

    path = with pkgs; [ ceph ];

    script = ''
      set -e
      MON_DIR="/var/lib/ceph/mon/ceph-ruby"
      if [[ ! -f "$MON_DIR/keyring" ]]; then
        mkdir -p "$MON_DIR"
        cp /etc/ceph/ceph.mon.keyring "$MON_DIR/keyring"
        chown -R ceph:ceph "$MON_DIR"
        ceph-mon --mkfs -i ruby --public-addr 192.168.111.66 --keyring "$MON_DIR/keyring"
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };
  };

  systemd.mounts = [{
    where  = "/data/cephfs";
    what   = "192.168.111.66:6789:/";
    type   = "ceph";
    options = "name=admin,secretfile=/etc/ceph/ceph.client.admin.keyring,_netdev";
    wantedBy = [ "multi-user.target" ];
  }];

  systemd.automounts = [{
    where  = "/data/cephfs";
    wantedBy = [ "multi-user.target" ];
  }];
}