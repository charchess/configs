{ config, pkgs, ... }:

{
  environment.etc."iscsi/nodes/iqn.2000-01.com.synology:Synelia.Target-ruby/192.168.111.69,3260,1/default" = {
    # NixOS va créer le chemin de répertoires nécessaire
    # et écrire le contenu ci-dessous dans un fichier nommé "default"
    text = ''
      node.name = iqn.2000-01.com.synology:Synelia.Target-ruby
      node.targetname = iqn.2000-01.com.synology:Synelia.Target-ruby
      node.conn[0].address = 192.168.111.69
      node.conn[0].port = 3260
      node.startup = automatic
    '';
  };

  # --- Configuration du client iSCSI ---
  services.openiscsi = {
    enable = true;
    # Définissez l'adresse IP de votre serveur iSCSI (la cible).
    # Le service tentera de découvrir et de se connecter automatiquement
    # à toutes les cibles exposées par ce serveur.
    name = "iqn.1993-08.org.debian:01:7df6d5b952ac-ruby";
  };

  # (Optionnel mais recommandé) Assurons-nous que le service de login est bien activé
  systemd.services.iscsi.wantedBy = [ "multi-user.target" ];
}