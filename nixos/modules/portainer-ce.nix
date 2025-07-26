{ lib, config, pkgs, ... }:
with lib;
let cfg = config.services.portainer-ce;
in
{
  options.services.portainer-ce = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "If enabled, run Portainer Community Edition.";
    };
    version = mkOption {
      type = types.str;
      default = "lts";
      description = "Container tag (lts, latest, 2.20.3, …).";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    networking.firewall.allowedTCPPorts = [ 8000 9443 ];

    systemd.services.portainer-ce = {
      description = "Portainer CE container";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ''${pkgs.docker}/bin/docker run \
          -d \
          --name portainer-ce \
          --restart unless-stopped \
          -p 8000:8000 \
          -p 9443:9443 \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v portainer_data:/data \
          portainer/portainer-ce:${cfg.version}'';
        ExecStop = ''${pkgs.docker}/bin/docker rm -f portainer-ce'';
      };
    };
  };
}