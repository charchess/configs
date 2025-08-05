# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, lib, ... }:

{
  imports =
  [
    ./networking.nix
    ../../common/nfs-mount.nix
    ./iscsi-connect.nix
    ../../common/chrony.nix
#    ../../modules/keepalived-ha.nix
#    ../../common/docker.nix
#    ../../modules/portainer.nix
#    ../../common/dockerswarm-join-or-init.nix
    ../../modules/node-reporter.nix
#    ../../modules/swarm-label-manager.nix
    ../../common/users.nix
#    ./ceph.nix
  ];

  sops = {
    enable = true;
    age.keyFile = "/chemin/vers/votre/age.key";
    # Vous pouvez aussi définir la clé publique ici
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # Utilise la clé SSH de l'hôte
    secrets."docker_login" = {
      # Chemin vers le fichier chiffré
      sopsFile = /etc/nixos/secrets/docker_login.yaml;
      # Dit à sops de ne pas changer le propriétaire du fichier déchiffré
      # (il sera lisible par root, ce qui est parfait pour notre script systemd)
      mode = "0400";
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

systemd.services.k3s = {
  serviceConfig.ExecStartPost = [
    (pkgs.writeShellScript "k3s-containerd-auth-config" ''
      set -e # Arrête le script si une commande échoue

      # On attend un peu pour être sûr que le fichier config.toml est bien là
      sleep 10

      CONFIG_FILE="/var/lib/rancher/k3s/agent/etc/containerd/config.toml"
      # CHEMIN VERS LE FICHIER DÉCHIFFRÉ, fourni par sops-nix
      DECRYPTED_AUTH_FILE="${config.sops.secrets.docker_login.path}"

      # On vérifie que les deux fichiers existent
      if [ -f "$CONFIG_FILE" ] && [ -f "$DECRYPTED_AUTH_FILE" ]; then
        # On lit le contenu du fichier d'authentification déchiffré
        # et on l'ajoute à la fin du fichier de config de containerd
        cat "$DECRYPTED_AUTH_FILE" | tee -a "$CONFIG_FILE" > /dev/null

        # On envoie un signal HUP pour que containerd recharge sa config
        pkill -SIGHUP containerd
      fi
    '').outPath
  ];
};


#  services.portainer = {
#    enable = false;
#    edition = "ee";
#    DataDir = "/data/nfs/containers/portainer";
#    version = "sts";
#  };

#  services.keepalived-ha = {
#    enable    = false;
#    interface = "vlan200";
#    vip       = "192.168.200.60/24";
#    priority  = 200;
#  };
}
