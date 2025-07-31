# File: modules/pkgs/ceph-keyrings.nix
# Refactored to return an attribute set containing paths to the generated keyrings.
# This makes it easier for other modules to reference specific keyring files directly.
#
# Usage:
# If initialAdminKey and initialBootstrapOsdKey are NOT provided (null),
# new keys are generated (backward compatible with single-node setup).
# If provided, these keys are used instead of generating new ones.
{ pkgs, lib, fsid, monName, monIp, initialAdminKey ? null, initialBootstrapOsdKey ? null, publicNetwork }:

let
  # The derivation that generates the keyrings
  keyringDerivation = pkgs.stdenv.mkDerivation {
    name = "ceph-keyrings-derivation-${monName}";

    buildInputs = [ pkgs.ceph ];

    # Explicitly convert null values to empty strings for shell interpolation safety.
    # This prevents the "cannot coerce null to a string" error when these parameters are not provided (i.e., null).
    _initialAdminKey = if initialAdminKey == null then "" else initialAdminKey;
    _initialBootstrapOsdKey = if initialBootstrapOsdKey == null then "" else initialBootstrapOsdKey;

    buildCommand = ''
      mkdir -p $out/keyrings # Store keyrings in a sub-directory for clarity

      # --- 1. Admin Keyring ---
      # Use the explicitly handled variable for safe shell interpolation
      if [ -n "$_initialAdminKey" ]; then
        echo "Using provided initialAdminKey for client.admin."
        ceph-authtool \
          --create-keyring $out/keyrings/ceph.client.admin.keyring \
          --add-key "$_initialAdminKey" -n client.admin \
          --cap mon 'allow *' \
          --cap osd 'allow *' \
          --cap mds 'allow *' \
          --cap mgr 'allow *'
      else
        echo "Generating new initialAdminKey for client.admin."
        ceph-authtool \
          --create-keyring $out/keyrings/ceph.client.admin.keyring \
          --gen-key -n client.admin \
          --cap mon 'allow *' \
          --cap osd 'allow *' \
          --cap mds 'allow *' \
          --cap mgr 'allow *'
      fi

      ADMIN_KEY_RAW=$(ceph-authtool $out/keyrings/ceph.client.admin.keyring --print-key -n client.admin)
      echo -n "$ADMIN_KEY_RAW" > $out/keyrings/ceph.client.admin.secret_key

      # --- 2. Bootstrap-OSD Keyring ---
      # Use the explicitly handled variable for safe shell interpolation
      if [ -n "$_initialBootstrapOsdKey" ]; then
        echo "Using provided initialBootstrapOsdKey for client.bootstrap-osd."
        ceph-authtool \
          --create-keyring $out/keyrings/ceph.client.bootstrap-osd.keyring \
          --add-key "$_initialBootstrapOsdKey" -n client.bootstrap-osd \
          --cap mon 'profile bootstrap-osd'
      else
        echo "Generating new initialBootstrapOsdKey for client.bootstrap-osd."
        ceph-authtool \
          --create-keyring $out/keyrings/ceph.client.bootstrap-osd.keyring \
          --gen-key -n client.bootstrap-osd \
          --cap mon 'profile bootstrap-osd'
      fi

      # --- 3. Monitor Keyring (mon.keyring) ---
      ceph-authtool \
        --create-keyring $out/keyrings/ceph.mon.keyring \
        --gen-key -n mon. --cap mon 'allow *'

      ceph-authtool $out/keyrings/ceph.mon.keyring \
        --import-keyring $out/keyrings/ceph.client.admin.keyring
      ceph-authtool $out/keyrings/ceph.mon.keyring \
        --import-keyring $out/keyrings/ceph.client.bootstrap-osd.keyring

      # --- 4. CephFS-Admin Keyring ---
      ADMIN_KEY_FOR_CEPHFS_ADMIN=$(ceph-authtool $out/keyrings/ceph.client.admin.keyring --print-key -n client.admin)
      ceph-authtool \
        --create-keyring $out/keyrings/ceph.client.cephfs-admin.keyring \
        --add-key "$ADMIN_KEY_FOR_CEPHFS_ADMIN" -n client.cephfs-admin \
        --cap mds 'allow *' \
        --cap osd 'allow *' \
        --cap mon 'allow r'

      # --- 5. Minimal ceph.conf ---
#      cat > $out/keyrings/ceph.conf <<EOF
#[global]
#fsid = ${fsid}
#mon initial members = ${monName}
#mon host = ${monIp}
#public network = ${publicNetwork}
#auth cluster required = cephx
#auth service required = cephx
#auth client required = cephx
#EOF
    '';
  };
in
# Return an attribute set with paths to the keyrings
{
  adminKeyring = "${keyringDerivation}/keyrings/ceph.client.admin.keyring";
  adminSecretKey = "${keyringDerivation}/keyrings/ceph.client.admin.secret_key";
  bootstrapOsdKeyring = "${keyringDerivation}/keyrings/ceph.client.bootstrap-osd.keyring";
  monKeyring = "${keyringDerivation}/keyrings/ceph.mon.keyring";
  cephfsAdminKeyring = "${keyringDerivation}/keyrings/ceph.client.cephfs-admin.keyring";
  cephConf = "${keyringDerivation}/keyrings/ceph.conf";

  # Expose the full derivation itself for compatibility if needed, though not recommended for file paths
  package = keyringDerivation;
}