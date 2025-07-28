{ lib, config, pkgs, ... }:
with lib;
let cfg = config.services.portainer-ee;
in
{
  options.services.portainer-ee = {
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
    networking.firewall.allowedTCPPorts = [ 80 443 8000 9443 10443 ];

    systemd.services.portainer-ee = {
      description = "Portainer CE container";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ''${pkgs.docker}/bin/docker run \
          -d \
          --name portainer-ee \
          --restart unless-stopped \
          -p 8000:8000 \
          -p 9443:9443 \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -v portainer_data:/data \
          portainer/portainer-ee:${cfg.version}'';
        ExecStop = ''${pkgs.docker}/bin/docker rm -f portainer-ee'';
      };
    };
  };
}