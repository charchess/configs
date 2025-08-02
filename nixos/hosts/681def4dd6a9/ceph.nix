{ config, lib, ... }:

let
  clusterConfig = import ../../common/ceph/cluster-config.nix { inherit lib; };
in {
  imports = [
    ../../modules/ceph
  ];

  services.ceph-custom = {
    enable = true;

    inherit (clusterConfig.cephCluster) nodes;

    thisNode = "emy";

    publicNetwork = "192.168.111.0/24";
    clusterNetwork = "192.168.111.0/24";

    # Activer le mode bootstrap pour le premier déploiement
    bootstrapSingleNode = true;
  };
}
