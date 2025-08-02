{ lib, pkgs, ... }:

with lib;

let
  # --- Sous-module pour les moniteurs ---
  monitorOptions = { ... }: {
    options = {
      enable = mkEnableOption "Ceph monitor on this node";
      address = mkOption {
        type = types.str;
        description = "IP address of the monitor.";
        example = "192.168.111.63";
      };
      initial = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this is an initial monitor for bootstrapping.";
      };
    };
  };

  # --- Sous-module pour les OSDs ---
  osdOptions = { ... }: {
    options = {
      host = mkOption {
        type = types.str;
        description = "Hostname where this OSD should run.";
      };
      device = mkOption {
        type = types.str;
        description = "The block device to use for this OSD (e.g., /dev/sdb).";
      };
    };
  };

in
{
  options.services.ceph-cluster = {
    enable = mkEnableOption "Custom Ceph cluster configuration";

    fsid = mkOption {
      type = types.str;
      description = "The unique identifier (FSID) for the Ceph cluster.";
      example = "d3611e34-d36a-45f8-9f86-0f10e5aefb5b";
    };

    # --- Réseaux ---
    publicNetwork = mkOption {
      type = types.str;
      description = "The public network CIDR for Ceph.";
      example = "192.168.111.0/24";
    };
    clusterNetwork = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The cluster network CIDR. If null, uses publicNetwork.";
    };

    # --- Définitions des moniteurs et OSDs ---
    monitors = mkOption {
      type = types.attrsOf (types.submodule monitorOptions);
      default = {};
      description = "Attribute set defining the monitors in the cluster, keyed by hostname.";
    };

    osds = mkOption {
      type = types.attrsOf (types.submodule osdOptions);
      default = {};
      description = "Attribute set defining the OSDs in the cluster, keyed by OSD ID (e.g., '0', '1').";
    };

    # --- Gestion des Secrets ---
    adminKeyringPath = mkOption {
      type = types.str;
      default = "/etc/ceph/ceph.client.admin.keyring";
      description = "Path to the admin keyring file.";
    };

    bootstrapKeyringPath = mkOption {
      type = types.str;
      default = "/var/lib/ceph/bootstrap-osd/ceph.keyring";
      description = "Path to the bootstrap keyring for OSDs.";
    };
  };
}