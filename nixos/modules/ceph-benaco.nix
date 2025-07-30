{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph-benaco;
  inherit (pkgs.callPackage ../helpers.nix {}) ensureUnitExists;
in
{

  ###### interface

  options.services.ceph-benaco = {

    enable = mkEnableOption "Ceph distributed filesystem";

    package = mkOption {
      type = types.package;
      default = pkgs.ceph;
      defaultText = literalExpression "pkgs.ceph";
      description = "Ceph package to use.";
    };

    fsid = mkOption {
      type = types.str;
      description = "Unique cluster identifier.";
    };

    clusterName = mkOption {
      type = types.str;
      default = "ceph";
      description = "Ceph cluster name.";
    };

    initialMonitors = mkOption {
      type = types.listOf (types.submodule {
        options = {
          hostname = mkOption {
            type = types.str;
            description = "Initial monitor hostname.";
          };
          ipAddress = mkOption {
            type = types.str;
            description = "Initial monitor IP address.";
          };
        };
      });
      description = "Initial monitors.";
    };

    mdsNodes = mkOption {
      type = types.listOf (types.submodule {
        options = {
          hostname = mkOption {
            type = types.str;
            description = "MDS hostname.";
          };
          ipAddress = mkOption {
            type = types.str;
            description = "MDS IP address.";
          };
        };
      });
      default = [];
      description = "MDS nodes.";
    };

    publicNetworks = mkOption {
      type = types.listOf types.str;
      description = "Public network(s) of the cluster.";
    };

    adminKeyring = mkOption {
      type = types.path;
      description = "Ceph admin keyring to install on the machine.";
    };

    monitor = {
      enable = mkEnableOption "Activate a Ceph monitor on this machine.";

      initialKeyring = mkOption {
        type = types.path;
        description = "Keyring file to use when initializing a new monitor";
        example = "/path/to/ceph.mon.keyring";
      };

      nodeName = mkOption {
        type = types.str;
        description = "Ceph monitor node name.";
        example = "node1";
      };

      bindAddr = mkOption {
        type = types.str;
        description = "IP address that the OSDs shall bind to.";
        example = "10.0.0.1";
      };

      advertisedPublicAddr = mkOption {
        type = types.str;
        description = "IP address that the monitor shall advertise.";
        example = "10.0.0.1";
      };
    };

    manager = {
      enable = mkEnableOption "Activate a Ceph manager on this machine.";

      nodeName = mkOption {
        type = types.str;
        description = "Ceph manager node name.";
        example = "node1";
      };
    };

    osdBindAddr = mkOption {
      type = types.str;
      description = "IP address that the OSDs shall bind to.";
      example = "10.0.0.1";
    };

    osdAdvertisedPublicAddr = mkOption {
      type = types.str;
      description = "IP address that the OSDs shall advertise.";
      example = "10.0.0.1";
    };

    osds = mkOption {
      default = {};
      example = {
        osd1 = {
          enable = true;
          bootstrapKeyring = "/path/to/ceph.client.bootstrap-osd.keyring";
          id = 1;
          uuid = "11111111-1111-1111-1111-111111111111";
          blockDevice = "/dev/sdb";
          blockDeviceUdevRuleMatcher = ''KERNEL=="sdb"'';
        };
      };
      description = ''
        Define multiple Ceph OSDs.
      '';
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "Activate a Ceph OSD on this machine.";
          bootstrapKeyring = mkOption {
            type = types.path;
            description = "Ceph OSD bootstrap keyring.";
          };
          id = mkOption {
            type = types.int;
            description = "The ID of this OSD. Must be unique in the Ceph cluster.";
          };
          uuid = mkOption {
            type = types.str;
            description = "The UUID of this OSD. Must be unique in the Ceph cluster.";
          };
          systemdExtraRequiresAfter = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "systemd units required before this OSD.";
          };
          skipZap = mkOption {
            type = types.bool;
            default = false;
            description = "Skip zapping the OSD device on creation.";
          };
          blockDevice = mkOption {
            type = types.str;
            description = "Block device used to store the OSD.";
          };
          blockDeviceUdevRuleMatcher = mkOption {
            type = types.str;
            description = "udev rule matcher for the block device.";
          };
          dbBlockDevice = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Separate block device for BlueStore DB.";
          };
          dbBlockDeviceUdevRuleMatcher = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "udev rule matcher for the DB block device.";
          };
        };
      });
    };

    mds = {
      enable = mkEnableOption "Activate a Ceph MDS on this machine.";
      nodeName = mkOption {
        type = types.str;
        description = "Ceph MDS node name.";
        example = "node1";
      };
      listenAddr = mkOption {
        type = types.str;
        description = "IP address that the MDS shall advertise.";
        example = "10.0.0.1";
      };
    };

    rgw = {
      enable = mkEnableOption "Activate a Ceph RADOS Gateway (RGW) on this machine";

      nodeName = mkOption {
        type = types.str;
        description = "Ceph RGW node name (usually the hostname).";
        example = "node1";
      };

      listenAddr = mkOption {
        type = types.str;
        description = "IP address that the RGW shall bind to.";
        example = "10.0.0.1";
      };

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "TCP port for the RGW beast frontend.";
      };
    };

    extraConfig = mkOption {
      type = types.str;
      default = "";
      description = "Additional ceph.conf settings.";
    };
  };

  ###### implementation

  config = let
    monDir = "/var/lib/ceph/mon/${cfg.clusterName}-${cfg.monitor.nodeName}";
    mgrDir = "/var/lib/ceph/mgr/${cfg.clusterName}-${cfg.manager.nodeName}";
    mdsDir = "/var/lib/ceph/mds/${cfg.clusterName}-${cfg.mds.nodeName}";
    rgwDir = "/var/lib/ceph/radosgw/${cfg.clusterName}-rgw.${cfg.rgw.nodeName}";

    ensureTransientCephDirs = ''
      install -m 770 -o ${config.users.users.ceph.name} -g ${config.users.groups.ceph.name} -d /var/run/ceph
    '';

    ensureCephDirs = ''
      install -m 3770 -o ${config.users.users.ceph.name} -g ${config.users.groups.ceph.name} -d /var/log/ceph
      install -m 770 -o ${config.users.users.ceph.name} -g ${config.users.groups.ceph.name} -d /var/run/ceph
      install -m 750 -o ${config.users.users.ceph.name} -g ${config.users.groups.ceph.name} -d /var/lib/ceph
      install -m 755 -o ${config.users.users.ceph.name} -g ${config.users.groups.ceph.name} -d /var/lib/ceph/mon
      install -m 755 -o ${config.users.users.ceph.name} -g ${config.users.groups.ceph.name} -d /var/lib/ceph/mgr
      install -m 755 -o ${config.users.users.ceph.name} -g ${config.users.groups.ceph.name} -d /var/lib/ceph/osd
    '';

    cephMonitoringSudoersCommandsAndPackages = [
      {
        package = pkgs.smartmontools;
        sudoersExtraRule = {
          users = [ config.users.users.ceph.name ];
          commands = [{
            command = "${lib.getBin pkgs.smartmontools}/bin/smartctl -x --json=o /dev/*";
            options = [ "NOPASSWD" ];
          }];
        };
      }
      {
        package = pkgs.nvme-cli;
        sudoersExtraRule = {
          users = [ config.users.users.ceph.name ];
          commands = [{
            command = "${lib.getBin pkgs.nvme-cli}/bin/nvme * smart-log-add --json /dev/*";
            options = [ "NOPASSWD" ];
          }];
        };
      }
    ];

    cephDeviceHealthMonitoringPathsOrPackages = with pkgs; [
      "/run/wrappers"
    ] ++ map ({ package, ... }: package) cephMonitoringSudoersCommandsAndPackages;

    ###### helpers pour les services

    makeCephOsdSetupSystemdService = localOsdServiceName: osdConfig:
      mkIf osdConfig.enable {
        description = "Initialize Ceph OSD";

        requires = osdConfig.systemdExtraRequiresAfter;
        after = osdConfig.systemdExtraRequiresAfter;

        path = with pkgs; [ util-linux lvm2 ];

        preStart = ''
          set -x
          ${ensureCephDirs}
          install -m 755 -o ceph -g ceph -d /var/lib/ceph/bootstrap-osd
          TMPFILE=$(mktemp --tmpdir=/var/lib/ceph/bootstrap-osd/)
          install -o ceph -g ceph ${osdConfig.bootstrapKeyring} "$TMPFILE"
          mv "$TMPFILE" /var/lib/ceph/bootstrap-osd/ceph.keyring
          udevadm trigger --name-match=${osdConfig.blockDevice}
          ${optionalString (osdConfig.dbBlockDevice != null) ''
            udevadm trigger --name-match=${osdConfig.dbBlockDevice}
          ''}
          udevadm settle
          ${optionalString (!osdConfig.skipZap) ''
            ${cfg.package}/bin/ceph-volume lvm zap ${osdConfig.blockDevice}
            ${optionalString (osdConfig.dbBlockDevice != null) ''
              ${cfg.package}/bin/ceph-volume lvm zap ${osdConfig.dbBlockDevice}
            ''}
          ''}
        '';

        script = ''
          set -euo pipefail
          until [ -f /etc/ceph/ceph.client.admin.keyring ]; do sleep 1; done
          OSD_SECRET=$(${cfg.package}/bin/ceph-authtool --gen-print-key)
          echo "{\"cephx_secret\": \"$OSD_SECRET\"}" | \
            ${cfg.package}/bin/ceph osd new ${osdConfig.uuid} ${toString osdConfig.id} -i - \
            -n client.bootstrap-osd -k ${osdConfig.bootstrapKeyring}
          mkdir -p /var/lib/ceph/osd/${cfg.clusterName}-${toString osdConfig.id}
          ln -s ${osdConfig.blockDevice} /var/lib/ceph/osd/${cfg.clusterName}-${toString osdConfig.id}/block
          ${optionalString (osdConfig.dbBlockDevice != null) ''
            ln -s ${osdConfig.dbBlockDevice} /var/lib/ceph/osd/${cfg.clusterName}-${toString osdConfig.id}/block.db
          ''}
          ${cfg.package}/bin/ceph-authtool --create-keyring /var/lib/ceph/osd/${cfg.clusterName}-${toString osdConfig.id}/keyring \
            --name osd.${toString osdConfig.id} --add-key $OSD_SECRET
          ${cfg.package}/bin/ceph-osd -i ${toString osdConfig.id} --mkfs --osd-uuid ${osdConfig.uuid} \
            --setuser ceph --setgroup ceph --osd-objectstore bluestore
          touch /var/lib/ceph/osd/.${toString osdConfig.id}.${osdConfig.uuid}.nix-existence
        '';

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PermissionsStartOnly = true;
          User = "ceph";
          Group = "ceph";
        };
        unitConfig.ConditionPathExists =
          "!/var/lib/ceph/osd/.${toString osdConfig.id}.${osdConfig.uuid}.nix-existence";
      };

    makeCephOsdSystemdService = localOsdServiceName: osdConfig:
      mkIf osdConfig.enable {
        description = "Ceph OSD";

        requires = [ (ensureUnitExists config "ceph-osd-setup-${localOsdServiceName}.service") ];
        requiredBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "local-fs.target"
          "time-sync.target"
          (ensureUnitExists config "ceph-osd-setup-${localOsdServiceName}.service")
        ];
        wants = [ "network.target" "local-fs.target" "time-sync.target" ];

        path = [ pkgs.getopt ] ++ cephDeviceHealthMonitoringPathsOrPackages;

        restartTriggers = [ config.environment.etc."ceph/ceph.conf".source ];

        preStart = ''
          ${ensureTransientCephDirs}
          ${lib.getLib cfg.package}/libexec/ceph/ceph-osd-prestart.sh \
            --cluster ${cfg.clusterName} --id ${toString osdConfig.id}
        '';

        serviceConfig = {
          LimitNOFILE = "1048576";
          LimitNPROC = "1048576";
          ExecStart = ''
            ${cfg.package}/bin/ceph-osd -f --cluster ${cfg.clusterName} \
              --id ${toString osdConfig.id} --setuser ceph --setgroup ceph \
              "--public_bind_addr=${cfg.osdBindAddr}" \
              "--public_addr=${cfg.osdAdvertisedPublicAddr}"
          '';
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
          ProtectHome = "true";
          ProtectSystem = "full";
          PrivateTmp = "true";
          TasksMax = "infinity";
        };
      };

    makeCephRgwSetupService = mkIf cfg.rgw.enable {
      description = "Initialize Ceph RGW";

      requires = [ (ensureUnitExists config "ceph-mgr.service") ];
      after = [ "ceph-mgr.service" ];

      path = [ cfg.package ];

      script = ''
        set -euo pipefail
        mkdir -p ${rgwDir}
        until [ -f /etc/ceph/ceph.client.admin.keyring ]; do sleep 1; done

        ${cfg.package}/bin/ceph auth get-or-create client.rgw.${cfg.rgw.nodeName} \
          mon 'allow rw' \
          osd 'allow rwx' \
          -o ${rgwDir}/keyring

        ${cfg.package}/bin/radosgw-admin realm create --rgw-realm=default --default || true
        ${cfg.package}/bin/radosgw-admin zonegroup create --rgw-zonegroup=default --master --default || true
        ${cfg.package}/bin/radosgw-admin zone create --rgw-zonegroup=default --rgw-zone=default --master --default || true

        touch ${rgwDir}/.nix_done
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "ceph";
        Group = "ceph";
      };
      unitConfig.ConditionPathExists = "!${rgwDir}/.nix_done";
    };

    makeCephRgwService = mkIf cfg.rgw.enable {
      description = "Ceph RADOS Gateway";

      requires = [ (ensureUnitExists config "ceph-rgw-setup-${cfg.rgw.nodeName}.service") ];
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "local-fs.target"
        "time-sync.target"
        (ensureUnitExists config "ceph-rgw-setup-${cfg.rgw.nodeName}.service")
      ];

      path = [ cfg.package ];

      serviceConfig = {
        ExecStart = ''
          ${cfg.package}/bin/radosgw -f \
            --cluster ${cfg.clusterName} \
            --name client.rgw.${cfg.rgw.nodeName} \
            --rgw-frontends "beast port=${toString cfg.rgw.port}" \
            --setuser ceph --setgroup ceph
        '';
        User = "ceph";
        Group = "ceph";
        Restart = "on-failure";
      };
    };

  in mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    networking.firewall = {
      allowedTCPPorts = [
        3300 # ceph msgr-v2
      ] ++ (optional cfg.rgw.enable cfg.rgw.port);
      allowedTCPPortRanges = [
        { from = 6800; to = 7300; }
      ];
    };

    environment.etc."ceph/ceph.conf".text = let
      commaSep = builtins.concatStringsSep ",";
    in ''
      [global]
      fsid = ${cfg.fsid}
      mon_initial_members = ${commaSep (map (mon: mon.hostname) cfg.initialMonitors)}
      mon_host = ${commaSep (map (mon: mon.ipAddress) cfg.initialMonitors)}

      auth_allow_insecure_global_id_reclaim = false
      mds_oft_prefetch_dirfrags = false
      osd_recovery_sleep_hdd = 0.0
      osd_scrub_min_interval = 345600
      osd_scrub_max_interval = 2419200
      osd_deep_scrub_interval = 2419200

      public_network = ${commaSep cfg.publicNetworks}
      auth_cluster_required = cephx
      auth_service_required = cephx
      auth_client_required = cephx

      ms_cluster_mode = secure
      ms_service_mode = secure
      ms_client_mode = secure

      ${cfg.extraConfig}
    '';

#    environment.etc."ceph/ceph.client.admin.keyring" = {
#      source = cfg.adminKeyring;
#      mode = "0600";
#      user = "ceph";
#      group = "ceph";
#    };

    users.users.ceph = {
      isNormalUser = false;
      isSystemUser = true;
      uid = 1001;
      group = "ceph";
    };
    users.groups.ceph = {
      gid = 499;
    };

    security.sudo.extraRules =
      map ({ sudoersExtraRule, ... }: sudoersExtraRule) (
        [
          {
            package = pkgs.smartmontools;
            sudoersExtraRule = {
              users = [ "ceph" ];
              commands = [{
                command = "${pkgs.smartmontools}/bin/smartctl -x --json=o /dev/*";
                options = [ "NOPASSWD" ];
              }];
            };
          }
          {
            package = pkgs.nvme-cli;
            sudoersExtraRule = {
              users = [ "ceph" ];
              commands = [{
                command = "${pkgs.nvme-cli}/bin/nvme * smart-log-add --json /dev/*";
                options = [ "NOPASSWD" ];
              }];
            };
          }
        ] ++ cephMonitoringSudoersCommandsAndPackages
      );

    services.udev.extraRules = concatStringsSep "\n" (
      mapAttrsToList (_localOsdServiceName: osdConfig: ''
        SUBSYSTEM=="block", ${osdConfig.blockDeviceUdevRuleMatcher}, OWNER="ceph", GROUP="ceph", MODE="0660"
        ${optionalString (osdConfig.dbBlockDeviceUdevRuleMatcher != null) ''
          SUBSYSTEM=="block", ${osdConfig.dbBlockDeviceUdevRuleMatcher}, OWNER="ceph", GROUP="ceph", MODE="0660"
        ''}
      '') cfg.osds
    );

    systemd.services = {
      ceph-mon-setup = mkIf cfg.monitor.enable {
        description = "Initialize ceph monitor";
        preStart = ensureCephDirs;
        script = let
          monmapNodes = concatStringsSep " " (
            concatMap (mon: [
              "--addv" mon.hostname "[v2:${mon.ipAddress}:3300,v1:${mon.ipAddress}:6789]"
            ]) cfg.initialMonitors
          );
        in ''
          set -euo pipefail
          rm -rf "${monDir}"
          echo "Initializing monitor."
          MONMAP_DIR=$(mktemp -d)
          ${cfg.package}/bin/monmaptool --create ${monmapNodes} --fsid ${cfg.fsid} "$MONMAP_DIR/monmap"
          echo "Running ceph-mon --mkfs to initialize ${monDir}..."
          ${cfg.package}/bin/ceph-mon --cluster ${cfg.clusterName} --mkfs \
            -i ${cfg.monitor.nodeName} --monmap "$MONMAP_DIR/monmap" --keyring ${cfg.monitor.initialKeyring} --mon-data "${monDir}" # <--- AJOUT CRUCIAL : Spécifie le répertoire de données pour mkfs
          # Vérifier si le répertoire des données du moniteur a bien été initialisé
          if [ -z "$(ls -A "${monDir}")" ]; then
            echo "ERROR: Monitor data directory '${monDir}' is still empty after mkfs! Setup failed." >&2
            exit 1 # Faire échouer le service de setup si le répertoire est vide
          else
            echo "Monitor data directory '${monDir}' initialized successfully by mkfs."
          fi
          rm -r "$MONMAP_DIR"
          touch ${monDir}/done
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PermissionsStartOnly = true;
          User = "ceph";
          Group = "ceph";
        };
        unitConfig.ConditionPathExists = "!${monDir}/done";
      };

      ceph-mon = mkIf cfg.monitor.enable {
        description = "Ceph monitor";
        requires = [ (ensureUnitExists config "ceph-mon-setup.service") ];
        requiredBy = [ "multi-user.target" ];
        after = [
          "network.target" "local-fs.target" "time-sync.target"
          (ensureUnitExists config "ceph-mon-setup.service")
        ];
        wants = [ "network.target" "local-fs.target" "time-sync.target" ];
        restartTriggers = [ config.environment.etc."ceph/ceph.conf".source ];
        preStart = ensureTransientCephDirs;
        serviceConfig = {
          LimitNOFILE = "1048576";
          LimitNPROC = "1048576";
          ExecStart = ''
            ${cfg.package}/bin/ceph-mon -f --cluster ${cfg.clusterName} --id ${cfg.monitor.nodeName} \
              --setuser ceph --setgroup ceph \
              "--public_bind_addr=${cfg.monitor.bindAddr}" \
              "--public_addr=${cfg.monitor.advertisedPublicAddr}"
          '';
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          PrivateDevices = "yes";
          ProtectHome = "true";
          ProtectSystem = "full";
          PrivateTmp = "true";
          TasksMax = "infinity";
          Restart = "on-failure";
        };
      };

      ceph-mgr-setup = mkIf cfg.manager.enable {
        description = "Initialize Ceph manager";
        preStart = ensureCephDirs;
        script = ''
          set -euo pipefail
          mkdir -p ${mgrDir}
          until [ -f /etc/ceph/ceph.client.admin.keyring ]; do sleep 1; done
          ${cfg.package}/bin/ceph auth get-or-create mgr.${cfg.manager.nodeName} \
            mon 'allow profile mgr' \
            mds 'allow *' \
            osd 'allow *' \
            -o ${mgrDir}/keyring
          touch "${mgrDir}/.nix_done"
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PermissionsStartOnly = true;
          User = "ceph";
          Group = "ceph";
        };
        unitConfig.ConditionPathExists = "!${mgrDir}/.nix_done";
      };

      ceph-mgr = mkIf cfg.manager.enable {
        description = "Ceph manager";
        requires = [ (ensureUnitExists config "ceph-mgr-setup.service") ];
        requiredBy = [ "multi-user.target" ];
        after = [
          "network.target" "local-fs.target" "time-sync.target"
          (ensureUnitExists config "ceph-mgr-setup.service")
        ];
        wants = [ "network.target" "local-fs.target" "time-sync.target" ];
        restartTriggers = [ config.environment.etc."ceph/ceph.conf".source ];
        preStart = ensureTransientCephDirs;
        serviceConfig = {
          LimitNOFILE = "1048576";
          LimitNPROC = "1048576";
          ExecStart = "${cfg.package}/bin/ceph-mgr -f --cluster ${cfg.clusterName} --id ${cfg.manager.nodeName} --setuser ceph --setgroup ceph";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
        };
      };

      ceph-mds-setup = mkIf cfg.mds.enable {
        description = "Initialize Ceph MDS";
        preStart = ensureCephDirs;
        script = ''
          set -euo pipefail
          mkdir -p ${mdsDir}
          until [ -f /etc/ceph/ceph.client.admin.keyring ]; do sleep 1; done
          ${cfg.package}/bin/ceph auth get-or-create mds.${cfg.mds.nodeName} \
            osd 'allow rwx' \
            mds 'allow' \
            mon 'allow profile mds' \
            -o ${mdsDir}/keyring
          touch "${mdsDir}/.nix_done"
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PermissionsStartOnly = true;
          User = "ceph";
          Group = "ceph";
        };
        unitConfig.ConditionPathExists = "!${mdsDir}/.nix_done";
      };

      ceph-mds = mkIf cfg.mds.enable {
        description = "Ceph MDS";
        requires = [ (ensureUnitExists config "ceph-mds-setup.service") ];
        requiredBy = [ "multi-user.target" ];
        after = [
          "network.target" "local-fs.target" "time-sync.target"
          (ensureUnitExists config "ceph-mds-setup.service")
        ];
        wants = [ "network.target" "local-fs.target" "time-sync.target" ];
        restartTriggers = [ config.environment.etc."ceph/ceph.conf".source ];
        preStart = ensureTransientCephDirs;
        serviceConfig = {
          LimitNOFILE = "1048576";
          LimitNPROC = "1048576";
          ExecStart = "${cfg.package}/bin/ceph-mds -f --cluster ${cfg.clusterName} --id ${cfg.mds.nodeName} --setuser ceph --setgroup ceph --public_addr=${cfg.mds.listenAddr}";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
        };
      };

    } // mapAttrs' (localOsdServiceName: osdConfig:
      nameValuePair "ceph-osd-setup-${localOsdServiceName}" (makeCephOsdSetupSystemdService localOsdServiceName osdConfig)
    ) cfg.osds
    // mapAttrs' (localOsdServiceName: osdConfig:
      nameValuePair "ceph-osd-${localOsdServiceName}" (makeCephOsdSystemdService localOsdServiceName osdConfig)
    ) cfg.osds
    // optionalAttrs cfg.rgw.enable {
      "ceph-rgw-setup-${cfg.rgw.nodeName}" = makeCephRgwSetupService;
      "ceph-rgw-${cfg.rgw.nodeName}"       = makeCephRgwService;
    };
  };
}