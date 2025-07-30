{ config, pkgs, ... }:

{
  # Activer le pare-feu
  networking.firewall.enable = true;

  # Configuration réseau par défaut (facultatif)
  networking = {
    firewall = {
      # Autoriser les connexions entrantes sur les ports spécifiés
      allowedTCPPorts = [ 22 53 80 443 8000 9000 9443 10443 ];
      allowedUDPPorts = [ 53 112 ];
    };
  };
}