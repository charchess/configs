{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-keyring;

  cephKeys = pkgs.callPackage ../../modules/ceph-keyrings.nix {
    inherit (cfg) fsid monName monIp;
  };
in
{
  options.services.ceph-keyring = {
    fsid    = mkOption { type = types.str; description = "Cluster FSID"; };
    monName = mkOption { type = types.str; description = "Monitor name"; };
    monIp   = mkOption { type = types.str; description = "Monitor IP"; };
  };

  config = {
    services.ceph-key-ring = {
      fsid    = "4b687c5c-5a20-4a77-8774-487989fd0bc7";
      monName = "emy";
      monIp   = "192.168.111.65";
    };

    environment.etc = {
      "ceph/ceph.client.admin.keyring" = {
        source = "${cephKeys}/ceph.client.admin.keyring";
      };

      "ceph/ceph.mon.keyring" = {
        source = "${cephKeys}/ceph.mon.keyring";
      };

      "ceph/ceph.client.bootstrap-osd.keyring" = {  
        source = "${cephKeys}/ceph.client.bootstrap-osd.keyring;
        mode   = "0600";
        user   = "ceph";
        group  = "ceph";
      };

#      "ceph/cephfs-admin.key" = {
#        source = "${cephKeys}/ceph.client.cephfs-admin.keyring";
#        mode   = "0400";
#        user   = "ceph";
#        group  = "ceph";
#      };
    };
  };
}