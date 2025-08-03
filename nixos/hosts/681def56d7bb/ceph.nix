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
    nodes.${config.services.ceph-custom.thisNode} = {
      hostname = "jade";
      address = clusterConfig.cephCluster.nodes.${config.services.ceph-custom.thisNode}.address;
      roles = ["mon" "mgr"];
    };
    publicNetwork = "192.168.111.0/24";
    clusterNetwork = "192.168.111.0/24";
    bootstrapSingleNode = false;
  };

  sops.secrets."ceph/jade-keyring" = {
    sopsFile = ./ceph-keyring-values.nix;
    owner = "ceph";
    group = "ceph";
  };
}
