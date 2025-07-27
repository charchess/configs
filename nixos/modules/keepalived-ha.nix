{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.keepalived-ha;
in
{
  options.services.keepalived-ha = {
    enable      = mkEnableOption "HA keepalived";
    interface   = mkOption { type = types.str; example = "vlan200"; };
    vip         = mkOption { type = types.str; example = "192.168.200.60/24"; };
    vrid        = mkOption { type = types.int;  default = 51; };
    priority    = mkOption { type = types.int;  description = "Higher = MASTER"; };
  };

  config = mkIf cfg.enable {
    boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

    services.keepalived = {
      enable = true;
      openfirewall = true;
      vrrpInstances.VI_1 = {
        interface       = cfg.interface;
        state           = if cfg.priority > 150 then "MASTER" else "BACKUP";
        virtualRouterId = cfg.vrid;
        priority        = cfg.priority;
        virtualIps      = [ { addr = cfg.vip; } ];
      };
    };

    networking.firewall = {
      enable = true;
      allowedUDPPorts = [ 112 ];
    };
  };
}