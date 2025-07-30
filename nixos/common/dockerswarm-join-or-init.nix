{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.docker-swarm;
in {
  options.services.docker-swarm = {
    enable = mkEnableOption "Docker Swarm join or init service";
    managerAddr = mkOption {
      type = types.str;
      description = "Address of the Docker Swarm manager";
      example = "192.168.111.63";
    };
    managerUser = mkOption {
      type = types.str;
      description = "SSH user for connecting to the Swarm manager";
      default = "root";
    };
    managerKey = mkOption {
      type = types.str;
      description = "Path to the SSH private key for connecting to the Swarm manager";
      example = "/root/.ssh/id_rsa";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.docker-swarm-join = {
      description = "Join or verify Docker Swarm membership";
      after = [ "docker.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          script = pkgs.writeShellScript "docker-swarm-join" ''
            #!/bin/sh
            set -e

            # Check if already part of a swarm
            SWARM_STATE=$(${pkgs.docker}/bin/docker info --format '{{.Swarm.LocalNodeState}}')
            if [ "$SWARM_STATE" = "active" ]; then
              echo "Node is already part of a swarm"
              exit 0
            fi

            # Get join token from manager
            JOIN_TOKEN=$(${pkgs.openssh}/bin/ssh -i ${cfg.managerKey} ${cfg.managerUser}@${cfg.managerAddr} \
              ${pkgs.docker}/bin/docker swarm join-token worker -q)

            # Join the swarm
            ${pkgs.docker}/bin/docker swarm join --token $JOIN_TOKEN ${cfg.managerAddr}:2377
          '';
        in "${script}";
        ExecStartPre = [
          "${pkgs.coreutils}/bin/sleep 5" # Give Docker time to start
        ];
      };
    };

    environment.systemPackages = with pkgs; [ docker openssh ];
  };
}