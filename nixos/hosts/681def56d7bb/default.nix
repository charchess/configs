# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, lib, ... }:

{
  imports =
  [
    ./networking.nix
    ../../common/firewall.nix
    ../../common/nfs-mount.nix
    ./iscsi-connect.nix
    ../../common/chrony.nix
    ../../modules/keepalived-ha.nix
    ../../common/docker.nix
#    ../../modules/portainer.nix
    ../../common/dockerswarm-join-or-init.nix
    ../../modules/node-reporter.nix
    ../../modules/swarm-label-manager.nix
    ../../common/users.nix
#    ./ceph.nix
  ];

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
  };

networking.firewall.allowedTCPPorts = [ 6443 ];

#  services.portainer = {
#    enable = false;
#    edition = "ee";
#    DataDir = "/data/nfs/containers/portainer";
#    version = "sts";
#  };

  services.keepalived-ha = {
    enable    = false;
    interface = "vlan200";
    vip       = "192.168.200.60/24";
    priority  = 200;
  };
}
