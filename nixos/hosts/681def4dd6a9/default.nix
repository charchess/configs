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

#    ./ceph.nix
  ];

  services.k3s = {
    enable = true;
    role = "server";
    serverAddr = "https://192.168.111.63:6443";
    token = "K104b4f27dc487a69f6c4e1652c9aa74107338631a4f5093c79466bebc535ca0289::server:ad2f1cd1b63765ff91ab630398bcd647";
  };

  networking.firewall.allowedTCPPorts = [ 6443 ];

#  services.keepalived-ha = {
#    enable    = true;
#    interface = "vlan200";
#    vip       = "192.168.200.60/24";
#    priority  = 150;
#  };
}
