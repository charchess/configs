{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.keepalived-ha;

  checkScript = pkgs.writeScriptBin "chk_keepalived.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VIP="${cfg.vip}"   # <-- injection depuis la config Nix
    PORT=9091

    if ${pkgs.curl}/bin/curl -s --max-time 2 "http://$VIP:$PORT/" \
        | ${pkgs.jq}/bin/jq -e '.["disk.feature.nfs"] == "true" and .["cpu.feature.avx"] == "true"' >/dev/null; then
      exit 0
    else
      exit 1
    fi
  '';
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
      vrrpInstances = {
        VI_1 = {
          interface = cfg.interface;
          state = if cfg.priority > 150 then "MASTER" else "BACKUP";
          virtualRouterId = cfg.vrid;
          priority = cfg.priority;
          virtualIps =  [ { addr = cfg.vip; } ];
          trackScripts = [ "chk_vip_service" ];
          extraConfig = ''
            authentication {
              auth_type PASS
              auth_pass mypass
            }
          '';
        };
      };
      vrrpScripts = {
        chk_vip_service = {
          script = "${checkScript}/bin/chk_keepalived.sh";
          interval = 5;
          timeout = 3;
          fall = 2;
          rise = 2;
          weight = 20;
        };
      };
    };


    networking.firewall = {
      enable = true;
      allowedUDPPorts = [ 112 ];
    };
  };
}