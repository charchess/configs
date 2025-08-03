# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  sops-nix-src = builtins.fetchTarball {
    url = "https://github.com/Mic92/sops-nix/archive/master.tar.gz";
  };
in
{
  imports =
  [
    "${sops-nix-src}/modules/sops"
    ./networking.nix
    ../../common/firewall.nix
    ../../common/nfs-mount.nix
    ./iscsi-connect.nix
    ../../common/chrony.nix
    ../../modules/keepalived-ha.nix
    ../../common/docker.nix
    ../../modules/portainer.nix
    ../../common/dockerswarm-join-or-init.nix
    ../../modules/node-reporter.nix
    ../../modules/swarm-label-manager.nix
    ../../common/users.nix
    ../../modules/portainer.nix

    ./ceph.nix

#    ../../common/sops.nix
  ];

  environment.systemPackages = with pkgs;
  [
    sops
    age
  ];

  sops = {
    defaultSopsFile = /etc/nixos/secrets/ceph/cluster.yaml;
    age.keyFile = "/etc/nixos/secrets/keys/age-keys.txt";
  };

  services.portainer = {
    enable = true;
    edition = "ee";
    DataDir = "/data/nfs/containers/portainer";
    version = "sts";
  };

  services.keepalived-ha = {
    enable    = true;
    interface = "vlan200";
    vip       = "192.168.200.60/24";
    priority  = 200;
  };
}
