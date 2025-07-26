{ config, lib, pkgs, modulesPath, ... }:

{
  networking = {
    hostName = "jade";
    nameservers = [ "192.168.200.60" ];

    vlans = {
      vlan200 = {
        id = 200;
        interface = "enp1s0";
      };
      vlan111 = {
        id = 111;
        interface = "enp1s0";
      };
    };

    interfaces = {
      enp3s0.useDHCP = false;
      vlan200.ipv4.addresses = [{
        address = "192.168.200.63";
        prefixLength = 24;
      }];
      vlan111.ipv4.addresses = [{
        address = "192.168.111.63";
        prefixLength = 24;
      }];
    };

    defaultGateway = {
      address = "192.168.200.1";
      interface = "vlan200";
    };
  };
}
