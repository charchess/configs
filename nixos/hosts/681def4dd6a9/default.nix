# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
  [
    ./networking.nix
    ../../configs/nfs-mount.nix
    ./iscsi-connect.nix
    ../../configs/chrony.nix
    ../../modules/keepalived-ha.nix
    ../../configs/docker.nix
    ../../modules/node-reporter.nix
#    ../../configs/swarm-label-manager.nix
    ../../configs/users.nix
    ../../configs/dockerswarm-join-or-init.nix

    ../../modules/ceph-keyring.nix
#    ./ceph-keyrings.nix      # module
    ./ceph-keyring-values.nix           # valeurs
    ../../modules/ceph-benaco.nix
   
    ./ceph.nix
  ];
  services.keepalived-ha = {
    enable    = true;
    interface = "vlan200";
    vip       = "192.168.200.60/24";
    priority  = 150;
  };
}
