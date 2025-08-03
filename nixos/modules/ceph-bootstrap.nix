{ config, pkgs, lib, ... }:

let
  fsid = "d3611e34-d36a-45f8-9f86-0f10e5aefb5b";
  hostname = config.networking.hostName;
  isBootstrapNode = hostname == "jade";
in
{
  systemd.services = lib.mkIf isBootstrapNode {
    ceph-mon-init = {
      description = "Initialize Ceph monitor (bootstrap)";
      wantedBy = [ "multi-user.target" ];
      before = [ "ceph-mon@jade.service" ];
      script = ''
        set -e
        if [ ! -d /var/lib/ceph/mon/ceph-jade ]; then
          ${pkgs.ceph}/bin/monmaptool --create --add jade 192.168.111.63 --fsid ${fsid} /tmp/monmap
          ${pkgs.ceph}/bin/ceph-mon --mkfs -i jade --monmap /tmp/monmap --keyring /dev/null
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "ceph";
        Group = "ceph";
      };
    };
  };
}

