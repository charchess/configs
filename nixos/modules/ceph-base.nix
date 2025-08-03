# /etc/nixos/modules/ceph-base.nix
{ config, lib, pkgs, ... }:

with lib;

{
  options.services.ceph-cluster = {
    enable = mkEnableOption "Ceph services";
    package = mkOption {
      type = types.package;
      default = pkgs.ceph;
      description = "The Ceph package to use.";
    };
    clusterName = mkOption {
      type = types.str;
      default = "ceph";
      description = "The name of the Ceph cluster.";
    };
    fsid = mkOption {
      type = types.str;
      description = "The FSID of the Ceph cluster. Must be a UUID.";
    };
    publicNetwork = mkOption {
      type = types.str;
      description = "The public network for Ceph (e.g., '192.168.200.0/24').";
    };
    clusterNetwork = mkOption {
      type = types.str;
      description = "The cluster network for Ceph (e.g., '192.168.111.0/24').";
      default = null; # Optional, if public and cluster networks are the same
    };

    keys = {
      adminKeyring = mkOption {
        type = types.str;
        description = "Content of ceph.client.admin.keyring.";
      };
      monKeyring = mkOption {
        type = types.str;
        description = "Content of ceph.mon.keyring.";
      };
    };
  };

  options.services.ceph-cluster.config = mkOption {
    type = types.attrs;
    default = {};
    description = "Ceph configuration options to be written to ceph.conf.";
  };

  config = mkIf config.services.ceph-cluster.enable {
    environment.systemPackages = [ config.services.ceph-cluster.package ];

    # Basic Ceph configuration
    # This will be written to /etc/ceph/ceph.conf
    services.ceph-cluster.config.global = {
      fsid = config.services.ceph-cluster.fsid;
      cluster_name = config.services.ceph-cluster.clusterName;
      
      public_network = config.services.ceph-cluster.publicNetwork;
      cluster_network = config.services.ceph-cluster.clusterNetwork;
      auth_cluster_required = "cephx";
      auth_service_required = "cephx";
      auth_client_required = "cephx";
    };

    # Ensure Ceph configuration directory exists
    systemd.tmpfiles.rules = [
      "d /etc/ceph 0755 root root -"
    ];

    environment.etc."ceph/ceph.client.admin.keyring".text = config.services.ceph-cluster.keys.adminKeyring;
    environment.etc."ceph/ceph.mon.keyring".text = config.services.ceph-cluster.keys.monKeyring;
  };
}