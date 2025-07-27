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

    # 2. bootstrap-osd keyring
    ceph-authtool \
      --create-keyring $out/ceph.client.bootstrap-osd.keyring \
      --gen-key -n client.bootstrap-osd \
      --cap mon 'profile bootstrap-osd'

    # 3. mon keyring avec toutes les clés
    ceph-authtool \
      --create-keyring $out/ceph.mon.keyring \
      --gen-key -n mon. --cap mon 'allow *'
    ceph-authtool $out/ceph.mon.keyring \
      --import-keyring $out/ceph.client.admin.keyring
    ceph-authtool $out/ceph.mon.keyring \
      --import-keyring $out/ceph.client.bootstrap-osd.keyring

    # 4. cephfs-admin keyring
    ceph-authtool \
      --create-keyring $out/ceph.client.cephfs-admin.keyring \
      --gen-key -n client.cephfs-admin \
      --cap mds 'allow *' \
      --cap osd 'allow *' \
      --cap mon 'allow r'

    # 4. cephfs-admin keyring
    ceph-authtool \
      --create-keyring $out/ceph.client.cephfs-admin.keyring \
      --gen-key -n client.cephfs-admin \
      --cap mds 'allow *' \
      --cap osd 'allow *' \
      --cap mon 'allow r'

    # Vérifier que la clé client.cephfs-admin a été créée
    if ! ceph-authtool --print-key $out/ceph.client.cephfs-admin.keyring | grep -q 'client.cephfs-admin'; then
      echo "Error: client.cephfs-admin key not found in ceph.client.cephfs-admin.keyring"
      exit 1
    fi

    # Extraire la clé secrète et l'écrire dans un fichier
    ceph-authtool --print-key $out/ceph.client.cephfs-admin.keyring | grep key | cut -d'=' -f2 | tr -d ' ' > $out/cephfs-admin.key

    # optionnel : créer aussi ceph.conf minimal
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