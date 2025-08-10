{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.keepalived-ha;

  checkScript = pkgs.writeScriptBin "chk_keepalived.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VIP="${lib.head (lib.splitString "/" cfg.vip)}"
    PORT=9101

    if ${pkgs.curl}/bin/curl -s --max-time 2 "http://$VIP:$PORT/" \
        | ${pkgs.jq}/bin/jq -e '.["disk.feature.nfs"] == "true" and .["cpu.feature.avx"] == "true"' >/dev/null; then
      exit 0
    else
      exit 1
    fi
  '';

  # Petit script notify écrit en Nix
  notifyScript = pkgs.writeShellScript "keepalived-notify" ''
    stateFile="/run/keepalived_state"
    case "$3" in
      MASTER) echo "MASTER $4" > "$stateFile" ;;
      BACKUP) echo "BACKUP $4" > "$stateFile" ;;
      FAULT)  echo "FAULT $4"  > "$stateFile" ;;
    esac
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

    systemd.tmpfiles.rules = [
      "f /run/keepalived_state 0644 root root -"
    ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "keepalived-state" ''
        [ -f /run/keepalived_state ] && cat /run/keepalived_state || echo "UNKNOWN"
      '')
    ];

    services.keepalived = {
      enable = true;
      vrrpInstances = {
        VI_1 = {
          extraConfig = ''
            notify "${notifyScript}"
          '';
          interface = cfg.interface;
          state = if cfg.priority > 150 then "MASTER" else "BACKUP";
          virtualRouterId = cfg.vrid;
          priority = cfg.priority;
          virtualIps =  [ { addr = cfg.vip; } ];
          trackScripts = [ "chk_vip_service" ];
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