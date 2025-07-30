{ config, pkgs, ... }:

{
  services.ceph = {
    osd = {
      enable = true;
      # Les daemons sont définis dans la config hôte
    };
  };

  # Service d'activation automatique des OSD
  systemd.services.ceph-osd-activate = {
    description = "Activate all Ceph OSDs";
    wantedBy = [ "multi-user.target" ];
    after = [ "ceph-mon.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "ceph";
      Group = "ceph";
      ExecStart = "${pkgs.ceph}/bin/ceph-volume lvm activate --all --no-systemd";
    };
  };
}