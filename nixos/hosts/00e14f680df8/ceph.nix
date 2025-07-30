{ config, pkgs, ... }:

{
  imports = [
    ../../common/ceph-base.nix
    ../../common/ceph-network.nix
    ../../common/ceph-firewall.nix
    ../../modules/ceph-mon.nix
    ../../modules/ceph-osd.nix
  ];

  # Configuration Ceph spécifique à ruby
  services.ceph = {
    osd = {
      enable = true;
      # OSD 2 sur /dev/sdc
      daemons = [ "2" ];
      extraConfig = {
        "osd.2.devs" = "/dev/sdc";
      };
    };
  };

  # Préparation du disque OSD
  systemd.services.prepare-ceph-osd-ruby = {
    description = "Prepare Ceph OSD disk on ruby";
    wantedBy = [ "multi-user.target" ];
    before = [ "ceph-osd@2.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'wipefs -a /dev/sdc || true'";
    };
  };
}