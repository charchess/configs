# /etc/nixos/hosts/000000000002/ceph.nix (for emy)
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../common/ceph-common.nix
  ];

  # Set hostname for this node (important for Ceph IDs)
  networking.hostName = "emy";

  # Configure network interfaces for Ceph
  networking.interfaces.enp1s0.ipv4.addresses = [
    {
      address = "192.168.111.65";
      prefixLength = 24;
    }
  ];

  services.ceph-cluster = {
    monitors = {
      emy = {
        enable = true;
        initial = true;
        address = "192.168.111.65";
      };
    };

    osds = {
      "1" = {
        host = "emy";
        device = "/dev/sda";
      };
    };

    mgrs = {
      emy = {
        enable = true;
        host = "emy";
      };
    };
  };
}
