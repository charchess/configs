{ config, lib, pkgs, modulesPath, ... }:

{
imports =
  [
    ../../configs/networking.nix
  ];

  networking = {
    hostName = "jade";

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
      enp1s0.useDHCP = false;
      vlan200.ipv4.addresses = [{
        address = "192.168.200.63";
        prefixLength = 24;
      }];
      vlan111.ipv4.addresses = [{
        address = "192.168.111.63";
        prefixLength = 24;
      }];
    };

  };
}
