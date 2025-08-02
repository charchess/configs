{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.services.portainer;
in
{
  options.services.portainer = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Activer Portainer.";
    };

    edition = mkOption {
      type = types.enum [ "ce" "ee" ];
      default = "ce";
      description = "Choisissez entre Portainer CE (Community Edition) et EE (Enterprise Edition).";
    };

      DataDir = mkOption {
      type = types.str;
      default = "/var/lib/portainer-data";
      description = "Emplacement du dossier de données pour Portainer CE.";
      defaultText = literalExpression "/var/lib/portainer-data";
    };

    version = mkOption {
      type = types.str;
      default = "latest";
      description = "Tag du conteneur (lts, latest, 2.20.3, ...).";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;
    networking.firewall.allowedTCPPorts = [ 80 443 8000 9000 9443 10443 ];

    systemd.services.portainer = {
      description = "Conteneur Portainer (${cfg.edition})";
      wantedBy = [ "multi-user.target" ];
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          image = if cfg.edition == "ce" then "portainer/portainer-ce" else "portainer/portainer-ee";
          dataDirArg = "-v ${cfg.DataDir}:/data";
        in
          ''${pkgs.docker}/bin/docker run \
            -d \
            --name portainer \
            --restart unless-stopped \
            -p 8000:8000 \
	    -p 9000:9000 \
            -p 9443:9443 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            ${dataDirArg} \
            ${image}:${cfg.version}'';
        ExecStop = ''${pkgs.docker}/bin/docker rm -f portainer'';
      };
    };
  };
}