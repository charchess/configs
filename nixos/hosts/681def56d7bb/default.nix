# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
  [
    ./networking.nix
    ../../configs/firewall.nix
    ../../configs/nfs-mount.nix
    ./iscsi-connect.nix
    ../../configs/chrony.nix
    ../../modules/keepalived-ha.nix
    ../../configs/docker.nix
    ../../modules/portainer-ce.nix
    ../../configs/dockerswarm-join-or-init.nix
    ../../modules/node-reporter.nix
    ../../modules/swarm-label-manager.nix
    ../../configs/users.nix

    ../../modules/ceph-keyring.nix      # module
    ./ceph-keyring-values.nix           # valeurs
    ../../modules/ceph-benaco.nix
    ./ceph.nix
  ];

  services.portainer-ce = {
    enable = true;
    version = "sts";
  };

  services.keepalived-ha = {
    enable    = true;
    interface = "vlan200";
    vip       = "192.168.200.60/24";
    priority  = 200;
  };
}
