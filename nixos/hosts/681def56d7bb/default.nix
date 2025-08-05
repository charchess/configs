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

networking.firewall = {
  trustedInterfaces = [ "cni0" "flannel.1" ];
  allowedTCPPorts = [ 2379 2380 6443 8472 9001 30778 ];
  extraCommands = ''
    iptables -t raw -A PREROUTING -s 10.42.0.0/16 -j ACCEPT
  '';
  extraStopCommands = ''
    iptables -t raw -D PREROUTING -s 10.42.0.0/16 -j ACCEPT || true
  '';
  };

  services.k3s = {
    enable = true;
    role = "server";
    clusterInit = true;
    extraFlags = [
      "--tls-san 192.168.111.63"
      "--advertise-address 192.168.111.63"
      "--bind-address 192.168.111.63"
      "--etcd-expose-metrics"
    ];
    manifests = {
      cert-manager = {
        enable = true;
        source = ../../manifests/cert-manager-helm.yaml;
      };
    };    
  };

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
