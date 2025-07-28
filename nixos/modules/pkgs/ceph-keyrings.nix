# File: modules/pkgs/ceph-keyrings.nix
{ pkgs, lib, fsid, monName, monIp }:

pkgs.stdenv.mkDerivation {
  name = "ceph-keyrings-${monName}";

  buildInputs = [ pkgs.ceph ];

  buildCommand = ''
    mkdir -p $out

    # 1. admin keyring
    ceph-authtool \
      --create-keyring $out/ceph.client.admin.keyring \
      --gen-key -n client.admin \
      --cap mon 'allow *' \
      --cap osd 'allow *' \
      --cap mds 'allow *' \
      --cap mgr 'allow *'

    # Extract the pure base64 key into a separate file from the GENERATED keyring
    ADMIN_KEY_RAW=$(ceph-authtool $out/ceph.client.admin.keyring --print-key -n client.admin)
    echo -n "$ADMIN_KEY_RAW" > $out/ceph.client.admin.secret_key

    # 2. bootstrap-osd keyring
    ceph-authtool \
      --create-keyring $out/ceph.client.bootstrap-osd.keyring \
      --gen-key -n client.bootstrap-osd \
      --cap mon 'profile bootstrap-osd'

    # 3. mon keyring with all keys
    ceph-authtool \
      --create-keyring $out/ceph.mon.keyring \
      --gen-key -n mon. --cap mon 'allow *'

    # Now, import the other keyrings into the mon.keyring
    ceph-authtool $out/ceph.mon.keyring \
      --import-keyring $out/ceph.client.admin.keyring
    ceph-authtool $out/ceph.mon.keyring \
      --import-keyring $out/ceph.client.bootstrap-osd.keyring

    # 4. cephfs-admin keyring : uses the admin key with restricted capabilities
    # Retrieve the admin key (from the complete keyring)
    ADMIN_KEY_FOR_CEPHFS_ADMIN=$(ceph-authtool $out/ceph.client.admin.keyring --print-key -n client.admin)

    # Create the cephfs-admin keyring and add the admin key for client.cephfs-admin
    ceph-authtool \
      --create-keyring $out/ceph.client.cephfs-admin.keyring \
      --add-key "$ADMIN_KEY_FOR_CEPHFS_ADMIN" -n client.cephfs-admin \
      --cap mds 'allow *' \
      --cap osd 'allow *' \
      --cap mon 'allow r'

    # optional: create a minimal ceph.conf
    cat > $out/ceph.conf <<EOF
[global]
fsid = ${fsid}
mon initial members = ${monName}
mon host = ${monIp}
public network = $(echo ${monIp} | cut -d/ -f1-2).0.0/16
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
EOF
'';
}
