# /etc/nixos/hosts/000000000003/ceph.nix (for ruby)
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../common/ceph-common.nix
  ];

  # Set hostname for this node (important for Ceph IDs)
  networking.hostName = "ruby";

  # Configure network interfaces for Ceph
  networking.interfaces.enp1s0.ipv4.addresses = [
    {
      address = "192.168.111.66";
      prefixLength = 24;
    }
  ];

  services.ceph-cluster = {
    monitors = {
      ruby = {
        enable = true;
        initial = true;
        address = "192.168.111.66";
      };
    };

    osds = {
      "2" = {
        host = "ruby";
        device = "/dev/sdc";
      };
    };

    # Ruby does not run a manager in this setup
    mgrs = {};
  };
}
