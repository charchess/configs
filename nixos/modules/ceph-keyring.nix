# /etc/nixos/modules/ceph-keyring.nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.ceph-keyring;

  cephKeys = pkgs.runCommand "ceph-keys" {
    buildInputs = [ pkgs.ceph ];
  } ''
    mkdir -p $out
    ceph-authtool --create-keyring $out/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
    ceph-authtool --create-keyring $out/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
    ceph-authtool --create-keyring $out/ceph.client.bootstrap-osd.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd'
  '';
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
        source = lib.mkDefault "${cephKeys}/ceph.client.admin.keyring";
      };

      "ceph/ceph.mon.keyring" = {
        source = lib.mkDefault "${cephKeys}/ceph.mon.keyring";
      };

      "ceph/ceph.client.bootstrap-osd.keyring" = {
        source = lib.mkDefault "${cephKeys}/ceph.client.bootstrap-osd.keyring";
      };
    };
  };
}


