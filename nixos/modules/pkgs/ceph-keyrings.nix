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

    # NOUVEAU : Extraire la clé admin pure (base64) dans un fichier séparé
    # L'option secretfile du client Ceph ne veut QUE la clé, pas l'entête ou "key =".
    ADMIN_KEY_RAW=$(grep "key =" $out/ceph.client.admin.keyring | awk '{print $3}')
    echo -n "$ADMIN_KEY_RAW" > $out/ceph.client.admin.secret_key

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

    # 4. cephfs-admin keyring : utilise la clé admin avec des capacités restreintes
    # Récupérer la clé de l'administrateur (de préférence depuis le keyring complet pour être sûr)
    ADMIN_KEY_FOR_CEPHFS_ADMIN=$(ceph-authtool $out/ceph.client.admin.keyring --print-key -n client.admin)

    # Créer le keyring cephfs-admin et y ajouter la clé admin pour le client.cephfs-admin
    ceph-authtool \
      --create-keyring $out/ceph.client.cephfs-admin.keyring \
      --add-key "$ADMIN_KEY_FOR_CEPHFS_ADMIN" -n client.cephfs-admin \
      --cap mds 'allow *' \
      --cap osd 'allow *' \
      --cap mon 'allow r'

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