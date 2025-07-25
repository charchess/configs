<<<<<<< HEAD
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


=======
# /etc/nixos/ceph.nix
# Version finale avec la syntaxe moderne pour logrotate.

{ lib, config, pkgs, ... }:

{
  config = {
    # 1. PRÉREQUIS SYSTÈME
    virtualisation.docker.enable = true;
    services.lvm.enable = true;
    
    # 2. CONFIGURATION DE CEPH
    services.ceph = {
      enable = true;
      global = {
        fsid = "864992b0-6315-11f0-b35b-00e14f680df8"; # Remplacez si nécessaire
      };
    };

    # 3. PAQUETS
    environment.systemPackages = [ pkgs.ceph pkgs.lvm2 ];

    # 4. COMPATIBILITÉ FHS
    system.activationScripts.ceph-fhs-compat = ''
      echo "Creating FHS compatibility symlinks for LVM tools..."
      mkdir -p /sbin
      ln -sf ${pkgs.lvm2}/bin/vgcreate /sbin/vgcreate
      ln -sf ${pkgs.lvm2}/bin/vgs /sbin/vgs
      ln -sf ${pkgs.lvm2}/bin/vgremove /sbin/vgremove
      ln -sf ${pkgs.lvm2}/bin/lvcreate /sbin/lvcreate
      ln -sf ${pkgs.lvm2}/bin/lvs /sbin/lvs
      ln -sf ${pkgs.lvm2}/bin/lvremove /sbin/lvremove
      ln -sf ${pkgs.lvm2}/bin/lvm /sbin/lvm
    '';

    # 5. GESTION DES LOGS (Syntaxe moderne)
    services.logrotate = {
      enable = true;
      # --- CORRECTION ICI ---
      # On utilise 'settings' au lieu de 'paths'.
      settings = {
        # La clé "cephadm" est un nom arbitraire que nous choisissons.
        "cephadm" = {
          # Le chemin du fichier de log reste le même.
          files = "/var/log/ceph/cephadm.log";
          # Les options sont maintenant des attributs.
          # C'est beaucoup plus lisible.
          daily = true;
          rotate = 7;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          su = "ceph ceph";
        };
      };
    };
  };
>>>>>>> 725251c8d7606856474d93d986ddff0ffed25239
}