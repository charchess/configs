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

      "ceph/ceph.mon.keyring" = {
        source = lib.mkDefault  "${cephKeys}/ceph.mon.keyring";
      };

      "ceph/ceph.client.bootstrap-osd.keyring" = { 
        source = lib.mkDefault "${cephKeys}/ceph.client.bootstrap-osd.keyring";
      };

      "ceph/cephfs-admin.key" = { 
        source = lib.mkDefault "${cephKeys}/cephfs-admin.key";
      };
    };
  };
}