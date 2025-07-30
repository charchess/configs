{ lib, config, pkgs, ... }:

{
  imports = [ ../modules/portainer-ce.nix ];

  services.portainer-ce.enable = true;
  services.portainer-ce.version = "sts";
}