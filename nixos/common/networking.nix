{ config, pkgs, lib, ... }:

{
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };
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

  allowedTCPPorts = [ 22 53 80 443 2379 2380 6443 8472 8000 9000 9001 9443 10443 30778 ];
  allowedUDPPorts = [ 53 112 8472 ];

  # -- DÉBUT DE LA CONFIGURATION DÉFINITIVE --
  # On utilise -I pour insérer les règles au début, leur donnant la priorité maximale.
  extraCommands = ''
    # --- RÈGLES POUR LE TRAFIC QUI TRAVERSE L'HÔTE (Pods/Conteneurs -> Extérieur) ---
    iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -I FORWARD 2 -s 10.42.0.0/16 -j ACCEPT
    iptables -I FORWARD 3 -s 172.17.0.0/16 -j ACCEPT

    # --- RÈGLES POUR LE TRAFIC GÉNÉRÉ PAR L'HÔTE LUI-MÊME (Téléchargement d'images, etc.) ---
    iptables -I OUTPUT 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -I OUTPUT 2 -p udp --dport 53 -j ACCEPT
    iptables -I OUTPUT 3 -p tcp --dport 53 -j ACCEPT
    iptables -I OUTPUT 4 -p tcp --dport 443 -j ACCEPT
    iptables -I OUTPUT 5 -p tcp --dport 80 -j ACCEPT
  '';

  # Commandes pour nettoyer proprement toutes nos règles.
  extraStopCommands = ''
    iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true
    iptables -D FORWARD -s 10.42.0.0/16 -j ACCEPT || true
    iptables -D FORWARD -s 172.17.0.0/16 -j ACCEPT || true
    iptables -D OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true
    iptables -D OUTPUT -p udp --dport 53 -j ACCEPT || true
    iptables -D OUTPUT -p tcp --dport 53 -j ACCEPT || true
    iptables -D OUTPUT -p tcp --dport 443 -j ACCEPT || true
    iptables -D OUTPUT -p tcp --dport 80 -j ACCEPT || true
  '';
  # -- FIN DE LA CONFIGURATION DÉFINITIVE --
  };

  };
}