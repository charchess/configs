{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-keyring;

  cephKeys = pkgs.callPackage ../pkgs/ceph-keyrings.nix {
    inherit (cfg) fsid monName monIp;
  };
in
{
  options.services.ceph-keyring = {
    fsid    = mkOption { type = types.str;  description = "Cluster FSID"; };
    monName = mkOption { type = types.str;  description = "Monitor name"; };
    monIp   = mkOption { type = types.str;  description = "Monitor IP"; };
  };

  config = {
    services.ceph-benaco.adminKeyring      = "${cephKeys}/ceph.client.admin.keyring";
    services.ceph-benaco.monitor.initialKeyring = "${cephKeys}/ceph.mon.keyring";
    services.ceph-benaco.osds.jade_osd.bootstrapKeyring = "${cephKeys}/ceph.client.bootstrap-osd.keyring";
  };
}