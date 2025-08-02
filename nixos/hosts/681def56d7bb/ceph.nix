{ config, lib, ... }:

let
  clusterConfig = import ../../common/ceph/cluster-config.nix { inherit lib; };
in {
  imports = [
    ../../modules/ceph
    ../../common/sops.nix
  ];

  services.ceph-custom = {
    enable = true;
    
    nodes = {
      jade = {
        hostname = "jade";
        address = clusterConfig.cephCluster.nodes.jade.address;
        roles = ["mon" "mgr"];
      };
    };
    
    thisNode = "jade";
    
    publicNetwork = "192.168.111.0/24";
    clusterNetwork = "192.168.111.0/24";
    
    # Désactiver le bootstrap après déploiement initial
    bootstrapSingleNode = false;
  };

  # Intégration des secrets via SOPS
  sops.secrets."ceph/jade-keyring" = {
    sopsFile = ./ceph-keyring-values.nix;
    owner = "ceph";
    group = "ceph";
  };
}
