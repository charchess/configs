# ceph-manual.nix
{ config, lib, pkgs, ... }:

let
  fsid      = "4b687c5c-5a20-4a77-8774-487989fd0bc7";
  monId     = "jade";
  monIP     = "192.168.111.63";
  osdDisk   = "/dev/disk/by-id/scsi-36001405be37301dd8e69d4612d9650dd";
  cephUser  = "ceph";
  cephMonIP  = "192.168.111.63";
  cephSecret = "AQAT0IJo0fagMhAA7M6DT1rqpw/T1WzUbDh3MQ==";
  mountPoint = "/data/cephfs";
in
{
  ##############################################################################
  # 1) Paquets et utilisateur
  ##############################################################################
  environment.systemPackages = with pkgs; [ ceph ceph-client ];

  users.groups.ceph = {};
  users.users.ceph  = {
    isSystemUser = true;
    group        = "ceph";
    extraGroups  = [ "disk" ];
    home         = "/var/lib/ceph";
    createHome   = true;
  };

  ##############################################################################
  # 2) Répertoires obligatoires
  ##############################################################################
  systemd.tmpfiles.rules = [
    "d /var/lib/ceph/mon/ceph-${monId} 0755 ${cephUser} ${cephUser} - -"
    "d /var/lib/ceph/osd/ceph-0        0755 ${cephUser} ${cephUser} - -"
    "d /var/lib/ceph/mgr/ceph-${monId} 0755 ${cephUser} ${cephUser} - -"
    "d ${mountPoint}                   0755 root        root        - -"
  ];

  ##############################################################################
  # 3) Service MON
  ##############################################################################
  systemd.services.ceph-mon = {
    description = "Ceph Monitor";
    after       = [ "network.target" ];
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = cephUser;
      Group     = cephUser;
      ExecStart = ''
        ${pkgs.ceph}/bin/ceph-mon \
          -f \
          --id ${monId} \
          --public-addr ${monIP}
      '';
      Restart   = "on-failure";
    };
  };

  ##############################################################################
  # 4) Service MGR
  ##############################################################################
  systemd.services.ceph-mgr = {
    description = "Ceph Manager";
    after       = [ "ceph-mon.service" ];
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = cephUser;
      Group     = cephUser;
      ExecStart = "${pkgs.ceph}/bin/ceph-mgr -f --id ${monId}";
      Restart   = "on-failure";
    };
  };


  systemd.services.ceph-mds = {
    description = "Ceph MDS";
    after       = [ "network-online.target" "ceph-mon.service" "ceph-mgr.service" ];
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = "ceph";
      Group     = "ceph";
      ExecStart = "${pkgs.ceph}/bin/ceph-mds -f --id jade";
      Restart   = "on-failure";
    };
  };

  ##############################################################################
  # 5) Service OSD (numéro 0)
  ##############################################################################
  systemd.services.ceph-osd-0 = {
    description = "Ceph OSD 0";
    after       = [ "ceph-mon.service" ];
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "simple";
      User      = cephUser;
      Group     = cephUser;
      ExecStart = "${pkgs.ceph}/bin/ceph-osd -f --id 0";
      Restart   = "on-failure";
    };
  };

  systemd.mounts = [
    {
      description = "CephFS mount";
      what        = "${cephMonIP}:/";
      where       = mountPoint;
      type        = "ceph";
      options     = "name=admin,secret=${cephSecret},noatime,_netdev";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network-online.target" ];
    }
  ];

  # Optionnel : automount
  systemd.automounts = [
    {
      where    = mountPoint;
      wantedBy = [ "multi-user.target" ];
    }
  ];

  ##############################################################################
  # 4) Dépendance réseau
  ##############################################################################
  systemd.services.systemd-networkd-wait-online.enable = true;


}