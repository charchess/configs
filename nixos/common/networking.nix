{ config, pkgs, lib, ... }:

{
  networking = {
    extraHosts =
      ''
        192.168.111.63 jade
        192.168.111.64 grenat
        192.168.111.65 emy
        192.168.111.66 ruby
      '';

    search = [ "admin.truxonline.com" ];
    nameservers = [ "192.168.200.60" ];

    defaultGateway = {
      address = "192.168.200.1";
      interface = "vlan200";
    };

#    firewall = {
#      trustedInterfaces = [ "cni0" "flannel.1" ];
#      allowedTCPPorts = [ 2379 2380 6443 8472 9001 30778 22 53 80 443 8000 9000 9443 10443 ];
#      allowedUDPPorts = [ 53 112 8472 ]; # J'ai ajouté le port 8472 pour flannel, c'est une bonne pratique
#    };

  firewall = {

    # Ouvre les ports pour les services tournant sur l'hôte lui-même (K3s API, SSH, etc.)
    # Ceci reste inchangé et est très important.
    allowedTCPPorts = [ 22 53 80 443 2379 2380 6443 8472 8000 9000 9001 9443 10443 30778 ];
    allowedUDPPorts = [ 53 112 8472 ];

    # -- DÉBUT DE LA SECTION POUR LA COEXISTENCE --
    # Remplace trustedInterfaces par des règles manuelles plus robustes.
    extraCommands = ''
      # Règle 1: Autorise le trafic de retour pour les connexions déjà établies.
      # C'est la règle la plus cruciale pour que le réseau fonctionne.
      iptables -I FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

      # Règle 2: Autorise les nouvelles connexions provenant du réseau des pods K3s (flannel).
      iptables -I FORWARD -s 10.42.0.0/16 -j ACCEPT

      # Règle 3: Autorise les nouvelles connexions provenant du réseau par défaut de Docker.
      iptables -I FORWARD -s 172.17.0.0/16 -j ACCEPT
    '';
 
    # Commande pour nettoyer proprement les règles lors d'un "nixos-rebuild switch".
    extraStopCommands = ''
      iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true
      iptables -D FORWARD -s 10.42.0.0/16 -j ACCEPT || true
      iptables -D FORWARD -s 172.17.0.0/16 -j ACCEPT || true
    '';
    # -- FIN DE LA SECTION POUR LA COEXISTENCE --
  };

  };
}