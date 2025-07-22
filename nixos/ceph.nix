# /etc/nixos/ceph.nix
# Version finale avec la syntaxe moderne pour logrotate.

{ lib, config, pkgs, ... }:

{
  config = {
    # 1. PRÉREQUIS SYSTÈME
    virtualisation.docker.enable = true;
    services.lvm.enable = true;
    
    # 2. CONFIGURATION DE CEPH
    services.ceph = {
      enable = true;
      global = {
        fsid = "864992b0-6315-11f0-b35b-00e14f680df8"; # Remplacez si nécessaire
      };
    };

    # 3. PAQUETS
    environment.systemPackages = [ pkgs.ceph pkgs.lvm2 ];

    # 4. COMPATIBILITÉ FHS
    system.activationScripts.ceph-fhs-compat = ''
      echo "Creating FHS compatibility symlinks for LVM tools..."
      mkdir -p /sbin
      ln -sf ${pkgs.lvm2}/bin/vgcreate /sbin/vgcreate
      ln -sf ${pkgs.lvm2}/bin/vgs /sbin/vgs
      ln -sf ${pkgs.lvm2}/bin/vgremove /sbin/vgremove
      ln -sf ${pkgs.lvm2}/bin/lvcreate /sbin/lvcreate
      ln -sf ${pkgs.lvm2}/bin/lvs /sbin/lvs
      ln -sf ${pkgs.lvm2}/bin/lvremove /sbin/lvremove
      ln -sf ${pkgs.lvm2}/bin/lvm /sbin/lvm
    '';

    # 5. GESTION DES LOGS (Syntaxe moderne)
    services.logrotate = {
      enable = true;
      # --- CORRECTION ICI ---
      # On utilise 'settings' au lieu de 'paths'.
      settings = {
        # La clé "cephadm" est un nom arbitraire que nous choisissons.
        "cephadm" = {
          # Le chemin du fichier de log reste le même.
          files = "/var/log/ceph/cephadm.log";
          # Les options sont maintenant des attributs.
          # C'est beaucoup plus lisible.
          daily = true;
          rotate = 7;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          su = "ceph ceph";
        };
      };
    };
  };
}