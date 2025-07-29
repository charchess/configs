# File: modules/ceph-keyring-config.nix
# This module is responsible for placing the generated Ceph keyrings into /etc/ceph.
# It now expects an attribute set of keyring paths from the ceph-keyrings.nix module.
{ config, lib, pkgs, ... }: # <--- Cette ligne est la signature correcte pour un module NixOS

{
  options.services.cephKeyringConfig = {
    enable = lib.mkEnableOption "Ceph Keyring Configuration";
    cephKeyrings = lib.mkOption {
      type = lib.types.attrs; # Expects an attribute set like { adminKeyring = ...; }
      description = "Attribute set of Ceph keyring paths, typically from pkgs.callPackage modules/pkgs/ceph-keyrings.nix.";
    };
  };

  config = lib.mkIf config.services.cephKeyringConfig.enable {
    # Ensure the /etc/ceph directory exists
    systemd.tmpfiles.rules = [
      "d /etc/ceph 0755 root root" # This creates the directory with correct permissions
      # Optionally, you could also use tmpfiles for keyring permissions if needed, e.g.:
      # "f /etc/ceph/ceph.client.admin.keyring 0600 ceph ceph"
    ];

    environment.etc."ceph/ceph.client.admin.keyring".source = config.services.cephKeyringConfig.cephKeyrings.adminKeyring;
    environment.etc."ceph/ceph.client.admin.secret_key".source = config.services.cephKeyringConfig.cephKeyrings.adminSecretKey;
    environment.etc."ceph/ceph.client.bootstrap-osd.keyring".source = config.services.cephKeyringConfig.cephKeyrings.bootstrapOsdKeyring;
    environment.etc."ceph/ceph.mon.keyring".source = config.services.cephKeyringConfig.cephKeyrings.monKeyring;
    environment.etc."ceph/ceph.client.cephfs-admin.keyring".source = config.services.cephKeyringConfig.cephKeyrings.cephfsAdminKeyring;

    # Add ceph user and group if they don't exist
    users.users.ceph = {
      group = "ceph";
      home = "/var/lib/ceph";
    };
    users.groups.ceph = {};

    # The actual permissions on the /etc/ceph/ keyrings will need to be managed separately.
    # We can add explicit systemd.tmpfiles.rules for each keyring if they are not automatically set by Ceph daemons.
    # For now, let's just get the NixOS build working.
  };
}


