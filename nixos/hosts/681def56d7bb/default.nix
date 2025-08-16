# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, lib, ... }:

{
  imports = [
    ./networking.nix
    ../../common/nfs-mount.nix
    ./iscsi-connect.nix
    ../../common/chrony.nix
    ../../modules/keepalived-ha.nix
#    ../../common/docker.nix
#    ../../modules/portainer.nix
#    ../../common/dockerswarm-join-or-init.nix
    ../../modules/node-reporter.nix
#    ../../modules/swarm-label-manager.nix
    ../../common/users.nix
    ../../common/k3s_cilium.nix
#    ../../common/sops.nix
  ];

  environment.systemPackages = with pkgs; [
    wget
    sops

    # Kubernetes
    cilium-cli
    kubernetes-helm
    tcpdump
  ];

#  services.portainer = {
#    enable = false;
#    edition = "ee";
#    DataDir = "/data/nfs/containers/portainer";
#    version = "sts";
#  };

  services.keepalived-ha = {
    enable    = true;
    interface = "vlan200";
    vip       = "192.168.200.60/24";
    priority  = 10;
  };

  
  networking.firewall.allowedTCPPorts = [
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
    4240 # Cilium health
    2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
    2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  ];
  networking.firewall.allowedUDPPorts = [
    8472 # k3s, flannel: required if using multi-node for inter-node networking
  ];
  services.k3s = {
    enable = true;
    role = "server";
    token = "LesLoutresCestQuandMemeMieuxHein";
    clusterInit = true; # Jade est intialisé, les autres noeud feront eux un join dessus.
    extraFlags = toString [
      "--tls-san 192.168.111.63"             # TPACPC
      "--advertise-address 192.168.111.63"   # sinon il utlise pas le reseau 111
      "--bind-address 192.168.111.63"        # et il ajoute pas l'ip au certificat pour le cluster
#      "--flannel-iface=vlan111"
      "--node-ip=192.168.111.63"
      "--flannel-backend=none"
#      "--disable-kube-proxy"
#      "--disable=servicelb"
#      "--disable-network-policy"
#      "--kubelet-arg=address=192.168.111.63"
      #"--disable traefik --disable servicelb --disable-kube-proxy --flannel-backend none --disable-network-policy"
      # "--debug" # Optionally add additional args to k3s
    ];
  };
}
