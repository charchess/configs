{ config, pkgs, ... }:

{
  # configuration du service de temps
  services.chrony.enable = true;
}