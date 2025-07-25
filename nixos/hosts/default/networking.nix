{ config, lib, pkgs, modulesPath, ... }:

{
  networking = {
    hostName = "VM-nix";
    nameservers = [ "192.168.200.60" ];

    interfaces = {
      enp1s0.useDHCP = true;

    defaultGateway = {
      address = "192.168.200.1";
      interface = "vlan200";
    };
  };
}