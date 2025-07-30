{ config, lib, pkgs, modulesPath, ... }:

{
imports =
  [
    ../../configs/networking.nix
  ];

  networking = {
    hostName = "emy";
    nameservers = [ "192.168.200.60" ];

    vlans = {
      vlan200 = {
        id = 200;
        interface = "enp3s0";
      };
      vlan111 = {
        id = 111;
        interface = "enp3s0";
      };
    };

    interfaces = {
      enp3s0.useDHCP = false;
      vlan200.ipv4.addresses = [
      {
        address = "192.168.200.65";
        prefixLength = 24;
      }];
      vlan111.ipv4.addresses = [
      {
        address = "192.168.111.65";
        prefixLength = 24;
      }];
    };

    defaultGateway = {
      address = "192.168.200.1";
      interface = "vlan200";
    };
  };
}