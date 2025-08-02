{ config, pkgs, ... }:

{
  imports = [
    ../../common/ceph-base.nix
    ../../common/ceph-network.nix
    ../../common/ceph-firewall.nix
    ../../modules/ceph-mon-join.nix
    ../../modules/ceph-osd.nix
  ];

  services.cephExtra = {
    disk = "/dev/sda";
    osdId = 1;
    monId = "emy";
    monAddr = "192.168.111.65";
  };
}