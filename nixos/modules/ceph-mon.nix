# /etc/nixos/modules/ceph-mon.nix
{ config, lib, pkgs, ... }:

with lib;

{
  options.services.ceph-cluster.monitors = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        enable = mkEnableOption "Ceph Monitor on this host";
        initial = mkOption {
          type = types.bool;
          default = false;
          description = "Whether this monitor is part of the initial monitor quorum.";
        };
        address = mkOption {
          type = types.str;
          description = "The IP address of this monitor.";
        };
        dataDir = mkOption {
          type = types.str;
          default = "/var/lib/ceph/mon-${name}";
          description = "Directory for monitor data.";
        };
      };
    }));
    default = {};
    description = "Configuration for Ceph Monitors.";
  };

  config = mkIf (builtins.hasAttr config.networking.hostName config.services.ceph-cluster.monitors && config.services.ceph-cluster.monitors.${config.networking.hostName}.enable) {
    services.ceph-cluster.config.mon = {
      mon_data = config.services.ceph-cluster.monitors.${config.networking.hostName}.dataDir;
      mon_initial_members = lib.concatStringsSep "," (mapAttrsToList (name: value: value.address) (filterAttrs (name: value: value.initial) config.services.ceph-cluster.monitors));
    };

    systemd.services."ceph-mon@${config.networking.hostName}" = {
      description = "Ceph Monitor Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${config.services.ceph-cluster.package}/bin/ceph-mon -f --cluster ${config.services.ceph-cluster.clusterName} --id ${config.networking.hostName} --public-addr ${config.services.ceph-cluster.monitors.${config.networking.hostName}.address}";
        Restart = "always";
        LimitNOFILE = 1048576;
        LimitNPROC = 1048576;
        TimeoutStopSec = 90;
      };
    };

    # Ensure monitor data directory exists
    systemd.tmpfiles.rules = [
      "d ${config.services.ceph-cluster.monitors.${config.networking.hostName}.dataDir} 0755 ceph ceph -"
    ];

    users.users.ceph = {
      isSystemUser = true;
      group = "ceph";
    };
    users.groups.ceph = {};

    systemd.services."ceph-mon-mkfs@${config.networking.hostName}" = {
      description = "Ceph Monitor Filesystem Initialization";
      wantedBy = [ "ceph-mon@${config.networking.hostName}.service" ];
      before = [ "ceph-mon@${config.networking.hostName}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.ceph}/bin/ceph-mon -i ${config.networking.hostName} --mkfs --monmap /etc/ceph/monmap --keyring /etc/ceph/ceph.mon.keyring --cluster ${config.services.ceph-cluster.clusterName} --mon-data ${config.services.ceph-cluster.monitors.${config.networking.hostName}.dataDir}";
        ConditionPathExists = "!${config.services.ceph-cluster.monitors.${config.networking.hostName}.dataDir}/done"; # Check for a 'done' file
      };
    };

    # Mark the directory as initialized after mkfs
    systemd.services."ceph-mon-mkfs-done@${config.networking.hostName}" = {
      description = "Mark Ceph Monitor Filesystem as Initialized";
      wantedBy = [ "ceph-mon-mkfs@${config.networking.hostName}.service" ];
      after = [ "ceph-mon-mkfs@${config.networking.hostName}.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/touch ${config.services.ceph-cluster.monitors.${config.networking.hostName}.dataDir}/done";
        ConditionPathExists = "!${config.services.ceph-cluster.monitors.${config.networking.hostName}.dataDir}/done";
      };
    };
  };
}
