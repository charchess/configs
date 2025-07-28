{ lib, config, pkgs, ... }:

{
  imports = [ ../modules/portainer-ee.nix ];

  services.portainer-ee.enable = true;
  services.portainer-ee.version = "sts";
}