{ config, pkgs, ... }:

{
  # configuration de docker
  virtualisation.docker.enable = true;
  
  networking.firewall = {
    allowedUDPPorts = [ 794 4789 7946 ];
    allowedTCPPorts = [ 80 443 794 2377 7946 ];
  };
}