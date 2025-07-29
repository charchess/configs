# modules/ceph-keyring-config.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.cephKeyringConfig;
in
{
  options.services.cephKeyringConfig = {
    enable = mkEnableOption "déploiement des fichiers de keyring Ceph générés par un package";

    cephKeyringsPackage = mkOption {
      type = types.package;
      description = "Package contenant les fichiers de keyring Ceph générés.";
      example = "pkgs.callPackage ../modules/pkgs/ceph-keyrings.nix { ... }";
    };
  };

  config = mkIf cfg.enable {
    environment.etc = {
      "ceph/ceph.client.admin.keyring" = {
        source = mkForce "${cfg.cephKeyringsPackage}/ceph.client.admin.keyring"; # <-- AJOUT DE mkForce
        mode = "0600";
        user = "ceph";
        group = "ceph";
      };

      "ceph/ceph.mon.keyring" = {
        source = mkForce "${cfg.cephKeyringsPackage}/ceph.mon.keyring"; # <-- AJOUT DE mkForce
        mode = "0600";
        user = "ceph";
        group = "ceph";
      };

      "ceph/ceph.client.bootstrap-osd.keyring" = {
        source = mkForce "${cfg.cephKeyringsPackage}/ceph.client.bootstrap-osd.keyring"; # <-- AJOUT DE mkForce
        mode = "0600";
        user = "ceph";
        group = "ceph";
      };

      "ceph/ceph.client.admin.secret_key" = {
        source = mkForce "${cfg.cephKeyringsPackage}/ceph.client.admin.secret_key"; # <-- AJOUT DE mkForce
        mode = "0400";
        user = "ceph";
        group = "ceph";
      };

      "ceph/ceph.client.cephfs-admin.keyring" = {
        source = mkForce "${cfg.cephKeyringsPackage}/ceph.client.cephfs-admin.keyring"; # <-- AJOUT DE mkForce
        mode = "0600";
        user = "ceph";
        group = "ceph";
      };
    };
  };
}