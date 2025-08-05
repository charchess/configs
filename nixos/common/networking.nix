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

    firewall = {
      trustedInterfaces = [ "cni0" "flannel.1" ];
      allowedTCPPorts = [ 2379 2380 6443 8472 9001 30778 22 53 80 443 8000 9000 9443 10443 ];
      allowedUDPPorts = [ 53 112 ];
        extraCommands = ''
        iptables -t raw -A PREROUTING -s 10.42.0.0/16 -j ACCEPT
      '';
    extraStopCommands = ''
      iptables -t raw -D PREROUTING -s 10.42.0.0/16 -j ACCEPT || true
    '';
    };
  };
}