{ config, pkgs, ... }:

{
  imports = [
    ../../common/ceph-base.nix
    ../../common/ceph-network.nix
    ../../common/ceph-firewall.nix
    ../../modules/ceph-mon.nix
    ../../modules/ceph-osd.nix
  ];

  # Configuration Ceph spécifique à emy
  services.ceph = {
    osd = {
      enable = true;
      # OSD 1 sur /dev/sda
      daemons = [ "1" ];
      extraConfig = {
        "osd.1.devs" = "/dev/sda";
      };
    };
  };

  # Préparation du disque OSD
  systemd.services.prepare-ceph-osd-emy = {
    description = "Prepare Ceph OSD disk on emy";
    wantedBy = [ "multi-user.target" ];
    before = [ "ceph-osd@1.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'wipefs -a /dev/sda || true'";
    };
  };
}