{ config, pkgs, ... }:

{
  # configuration des NFS
  # Définition des points de montage NFS
  fileSystems = {
    "/data/nfs/downloads" = {
      device = "192.168.111.69:/volume3/Downloads";
      fsType = "nfs4";
      options = [
        "rw"
        "relatime"
        "vers=4.1"
        "rsize=8192"
        "wsize=8192"
        "hard"
        "proto=tcp"
        "timeo=14"
        "retrans=2"
        "sec=sys"
        "clientaddr=192.168.111.65"
        "local_lock=none"
        "_netdev" # Indique que c'est un montage réseau, à monter après la mise en place du réseau
      ];
    };

    "/data/nfs/containers" = {
      # ATTENTION : Adaptez le chemin du partage sur le serveur NFS
      device = "192.168.111.69:/volume3/docker";
      fsType = "nfs4";
      # Vous pouvez copier les mêmes options ou les adapter si besoin
      options = [ "rw" "relatime" "vers=4.1" "hard" "proto=tcp" "_netdev" ];
    };

    "/data/nfs/content" = {
      # ATTENTION : Adaptez le chemin du partage sur le serveur NFS
      device = "192.168.111.69:/volume3/Content";
      fsType = "nfs4";
      options = [ "rw" "relatime" "vers=4.1" "hard" "proto=tcp" "_netdev" ];
    };
  };
}