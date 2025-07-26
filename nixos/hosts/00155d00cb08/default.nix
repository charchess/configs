# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
  [
    ./networking.nix
    ../../modules/nfs-mount.nix
    ../../modules/iscsi-connect.nix
    ../../modules/chrony.nix
    ../../modules/keepalived.nix
    ../../modules/docker.nix
    ../../modules/ceph.nix
    ../../modules/node-reporter.nix
    ../../modules/swarm-label-manager.nix
    ../../modules/users.nix
  ];


}