{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ceph.osd;
  cephConfig = config.services.ceph.config;
in {
  options.services.ceph.osd = {
    enable = mkEnableOption "Ceph OSD service";

    device = mkOption {
      type = types.str;
      description = "The device path for the OSD (e.g., "/dev/sdb").";
      example = "/dev/sdb";
    };

    # Optional: OSD ID if you want to explicitly set it (usually auto-generated)
    osdId = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Optional: Explicit OSD ID. If null, Ceph will assign one.";
    };

    # Optional: OSD data directory (if not using a whole device)
    dataDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional: The directory where OSD data will be stored. If not specified, the OSD will use the whole device.";
    };
  };

  config = mkIf cfg.enable {
    services.ceph.config = {
      osd = {
        osd_data = mkIf (cfg.dataDir != null) cfg.dataDir;
        osd_journal_size = 1024; # Example: 1GB journal size
        osd_max_backfills = 10;
        osd_recovery_max_active = 3;
        osd_recovery_op_priority = 10;
      };
    };

    systemd.services."ceph-osd@${cfg.osdId or (baseNameOf cfg.device)}" = {
      description = "Ceph OSD on ${cfg.device}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];

      # This command will prepare and activate the OSD.
      # For whole devices, ceph-volume lvm create is typically used.
      # For directories, ceph-osd -i <id> --mkfs --mkjournal --osd-data <dir>
      # This is a simplified example. A real-world setup might involve
      # ceph-volume or more complex pre-setup.
      script =
        let
          osdIdArg = if cfg.osdId != null then "-i ${toString cfg.osdId}" else "";
          dataDirArg = if cfg.dataDir != null then "--osd-data ${cfg.dataDir}" else "";
        in
        ''
          ${pkgs.ceph}/bin/ceph-volume lvm create --data ${cfg.device} --cluster ${cephConfig.global.cluster_name}
          # The above command handles mkfs, mkjournal, and activation.
          # If using a directory, you might need:
          # mkdir -p ${cfg.dataDir}
          # ${pkgs.ceph}/bin/ceph-osd ${osdIdArg} ${dataDirArg} --mkfs --mkjournal
          # ${pkgs.ceph}/bin/ceph-osd ${osdIdArg} ${dataDirArg} --setuser ceph --setgroup ceph
        '';

      serviceConfig = {
        Type = "forking";
        ExecStart = "${pkgs.ceph}/bin/ceph-osd -f ${osdIdArg} ${dataDirArg}";
        Restart = "on-failure";
        User = "ceph";
        Group = "ceph";
        LimitNOFILE = 1048576;
      };
    };

    # Ensure ceph user and group exist
    users.users.ceph = {
      isSystem = true;
      group = "ceph";
    };
    users.groups.ceph = {
      isSystem = true;
    };

    # Ensure the device is available and not mounted by NixOS itself
    # This is a placeholder. In a real setup, you'd ensure the device
    # is not part of your NixOS filesystem configuration.
    # You might need to add udev rules or pre-mount checks.
  };
}