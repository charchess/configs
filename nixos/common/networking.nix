{ config, pkgs, lib, ... }:

{
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;
  };
  networking = {
#    nftables.enable = true;
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
      allowedTCPPorts = [ 22 53 80 443 2379 2380 4240 6443 8472 8000 9000 9001 9443 10250 10443 30778 ];
      allowedUDPPorts = [ 53 112 8472 ];
      extraCommands = ''
#        nft add rule inet filter input ip daddr 224.0.0.18/32 accept
#        nft add rule inet filter output ip daddr 224.0.0.18/32 accept
        iptables -I INPUT   -d 224.0.0.18/32 -j ACCEPT
        iptables -I OUTPUT  -d 224.0.0.18/32 -j ACCEPT
      '';
    };
  };
}