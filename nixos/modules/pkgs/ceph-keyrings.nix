{ pkgs, lib, fsid, monName, monIp }:

pkgs.stdenv.mkDerivation {
  name = "ceph-keyrings-${monName}";

  buildCommand = ''
    mkdir -p $out

    ${pkgs.ceph}/bin/ceph-authtool \
      --create-keyring $out/ceph.client.admin.keyring \
      --gen-key -n client.admin \
      --cap mon 'allow *' \
      --cap osd 'allow *' \
      --cap mds 'allow *' \
      --cap mgr 'allow *'

    ${pkgs.ceph}/bin/ceph-authtool \
      --create-keyring $out/ceph.client.bootstrap-osd.keyring \
      --gen-key -n client.bootstrap-osd \
      --cap mon 'profile bootstrap-osd'

    ${pkgs.ceph}/bin/ceph-authtool \
      --create-keyring $out/ceph.mon.keyring \
      --gen-key -n mon. --cap mon 'allow *'
    ${pkgs.ceph}/bin/ceph-authtool $out/ceph.mon.keyring \
      --import-keyring $out/ceph.client.admin.keyring
    ${pkgs.ceph}/bin/ceph-authtool $out/ceph.mon.keyring \
      --import-keyring $out/ceph.client.bootstrap-osd.keyring
  '';
}