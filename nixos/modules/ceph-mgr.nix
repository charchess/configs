# /etc/nixos/modules/ceph-mgr.nix
{ config, lib, pkgs, ... }:

with lib;

{
  options.services.ceph-cluster.mgrs = mkOption {
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        enable = mkEnableOption "Ceph Manager on this host";
        host = mkOption {
          type = types.str;
          description = "The hostname of the node where this MGR runs.";
        };
        dataDir = mkOption {
          type = types.str;
          default = "/var/lib/ceph/mgr-${name}";
          description = "Directory for manager data.";
        };
      };
    }));
    default = {};
    description = "Configuration for Ceph Managers.";
  };

  config = mkIf (builtins.any (mgr: mgr.host == config.networking.hostName) (attrValues config.services.ceph-cluster.mgrs)) {
    services.ceph-cluster.config.mgr = {
      mgr_data = config.services.ceph-cluster.mgrs.${config.networking.hostName}.dataDir;
    };

    systemd.services = listToAttrs (mapAttrsToList (mgrName: mgrValue: 
      let
        mgrId = mgrName; # MGR ID is the attribute name (e.g., "a")
        mgrDataDir = mgrValue.dataDir;
      in
      {
        name = "ceph-mgr@${mgrId}";
        value = {
          description = "Ceph Manager Daemon for ${mgrId}";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          requires = [ "network-online.target" ];
          serviceConfig = {
            ExecStart = "${config.services.ceph-cluster.package}/bin/ceph-mgr -f --cluster ${config.services.ceph-cluster.clusterName} --id ${mgrId}";
            Restart = "always";
            LimitNOFILE = 1048576;
            LimitNPROC = 1048576;
            TimeoutStopSec = 90;
          };
        };
      }
    ) (filterAttrs (name: value: value.host == config.networking.hostName) config.services.ceph-cluster.mgrs));

    # Ensure manager data directory exists
    systemd.tmpfiles.rules = mapAttrsToList (mgrName: mgrValue:
      "d ${mgrValue.dataDir} 0755 ceph ceph -"
    ) (filterAttrs (name: value: value.host == config.networking.hostName) config.services.ceph-cluster.mgrs);

    users.users.ceph = {
      isSystemUser = true;
      group = "ceph";
    };
    users.groups.ceph = {};
  };
}
