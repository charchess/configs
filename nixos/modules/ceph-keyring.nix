# File: modules/ceph-keyring.nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.ceph-keyring;
  cephKeys = pkgs.callPackage ./pkgs/ceph-keyrings.nix {
    inherit (cfg) fsid monName monIp;
  };
in
{
  options.services.ceph-keyring = {
    enable  = mkEnableOption "generation of Ceph keyring files";
    fsid    = mkOption { type = types.str;  description = "Cluster FSID"; };
    monName = mkOption { type = types.str;  description = "Monitor name"; };
    monIp   = mkOption { type = types.str;  description = "Monitor IP"; };
  };

  config = mkIf cfg.enable {
    environment.etc = {
      "ceph/ceph.client.admin.keyring" = {
        source = lib.mkDefault  "${cephKeys}/ceph.client.admin.keyring";
      };

      # NOUVEAU : Ajout du fichier ne contenant QUE la clé secrète admin
      "ceph/ceph.client.admin.secret_key" = {
        source = lib.mkDefault  "${cephKeys}/ceph.client.admin.secret_key";
        # Assurez-vous que les permissions sont restrictives pour une clé
        mode = "0400"; # Lecture seule pour le propriétaire (root)
        user = "root";
        group = "root";
      };

      "ceph/ceph.mon.keyring" = {
        source = lib.mkDefault  "${cephKeys}/ceph.mon.keyring";
      };

      "ceph/ceph.client.bootstrap-osd.keyring" = {
        source = lib.mkDefault "${cephKeys}/ceph.client.bootstrap-osd.keyring";
      };

      # Assurez-vous que cette ligne est bien présente pour cephfs-admin
      "ceph/ceph.client.cephfs-admin.keyring" = {
        source = lib.mkDefault "${cephKeys}/ceph.client.cephfs-admin.keyring";
      };
    };
  };
}