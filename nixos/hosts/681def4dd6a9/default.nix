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
    ../../modules/keepalived-ha.nix
    ../../common/docker.nix
    ../../modules/node-reporter.nix
#    ../../common/swarm-label-manager.nix
    ../../common/users.nix
    ../../common/dockerswarm-join-or-init.nix

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
    serverAddr = "https://192.168.111.63:6443";
    token = "K1034e563450f37fb73f7aa0e4edb11ab86bf24d3220a92cc900f0c22f52e908223::server:LesLoutresCestQuandMemeMieuxHein";
    extraFlags = [
      "--tls-san 192.168.111.65"
      "--advertise-address 192.168.111.65"
      "--bind-address 192.168.111.65"
      "--etcd-expose-metrics"
    ];
    clusterInit = false;
  };

  services.keepalived-ha = {
    enable    = true;
    interface = "vlan200";
    vip       = "192.168.200.60/24";
    priority  = 150;
  };
}
