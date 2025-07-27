{ config, lib, pkgs, modulesPath, ... }:

{
  networking = {
    hostName = "ruby";
    nameservers = [ "192.168.200.60" ];
    search = [ "admin.truxonline.com" ];

    vlans = {
      vlan200 = {
        id = 200;
        interface = "enp2s0";
      };
      vlan111 = {
        id = 111;
        interface = "enp2s0";
      };
    };

    interfaces = {
      enp2s0.useDHCP = false;
      vlan200.ipv4.addresses = [
      {
        address = "192.168.200.66";
        prefixLength = 24;
      }];
      vlan111.ipv4.addresses = [
      {
        address = "192.168.111.66";
        prefixLength = 24;
      }];
    };

    defaultGateway = {
      address = "192.168.200.1";
      interface = "vlan200";
    };
  };
}