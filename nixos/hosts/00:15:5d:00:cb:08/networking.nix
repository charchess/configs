{ config, lib, pkgs, modulesPath, ... }:

{
  networking = {
    hostName = "VM-nix";
    nameservers = [ "192.168.200.60" ];

    interfaces = {
      eth0.useDHCP = false;
      eth0.ipv4.addresses = [
      {
        address = "192.168.200.68";
        prefixLength = 24;
      }];
    };

    defaultGateway = {
      address = "192.168.200.1";
      interface = "eth0";
    };
  };
}