# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
  [
    ./networking.nix
    ../../common/nfs-mount.nix
    ./iscsi-connect.nix
    ../../common/chrony.nix
#    ../../modules/keepalived-ha.nix
    ../../common/docker.nix
    ../../modules/node-reporter.nix
#    ../../common/swarm-label-manager.nix
    ../../common/users.nix
    ../../common/dockerswarm-join-or-init.nix

    ./ceph.nix
  ];

#  services.keepalived-ha = {
#    enable    = true;
#    interface = "vlan200";
#    vip       = "192.168.200.60/24";
#    priority  = 150;
#  };
}
