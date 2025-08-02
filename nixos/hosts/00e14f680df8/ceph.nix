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
    disk = "/dev/sdc";
    osdId = 2;
    monId = "ruby";
    monAddr = "192.168.111.66";
  };
}