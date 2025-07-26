# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
  [
    ./networking.nix
    ../../configs/nfs-mount.nix
    ../../configs/iscsi-connect.nix # a corriger car specifique par machine
    ../../configs/chrony.nix
    ../../configs/keepalived.nix # prevoir un master/slave
    ../../configs/docker.nix
    ../../configs/portainer.nix
#    ../../configs/ceph.nix
#    ../../configs/node-reporter.nix
#    ../../configs/swarm-label-manager.nix
    ../../configs/users.nix
  ];


}
