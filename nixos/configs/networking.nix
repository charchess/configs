{ config, pkgs, lib, ... }:

{
  networking.extraHosts =
    ''
      192.168.111.63 jade
      192.168.111.64 grenat
      192.168.111.65 emy
      192.168.111.66 ruby
    '';
}