{ config, pkgs, ... }:

{
  imports = [
    ../../common/ceph-base.nix
    ../../common/ceph-network.nix
    ../../common/ceph-firewall.nix
    ../../modules/ceph-mon.nix
    ../../modules/ceph-osd.nix
  ];

  # Configuration Ceph spécifique à jade
  services.ceph = {
    osd = {
      enable = true;
      # OSD 0 sur /dev/sdb
      daemons = [ "0" ];
      extraConfig = {
        "osd.0.devs" = "/dev/sdb";
      };
    };
  };

  # Préparation du disque OSD
  systemd.services.prepare-ceph-osd-jade = {
    description = "Prepare Ceph OSD disk on jade";
    wantedBy = [ "multi-user.target" ];
    before = [ "ceph-osd@0.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'wipefs -a /dev/sdb || true'";
    };
  };
}