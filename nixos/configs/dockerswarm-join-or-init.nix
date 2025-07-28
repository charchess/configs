    { config, lib, pkgs, ... }:

    let
      managerAddr = "192.168.111.60";
      managerPort = "2377";
      agentTag = "sts";
      networkName = "portainer_agent_network";
    in
    {
      systemd.services.docker-swarm-join-or-init = {
        description = "Join existing Docker Swarm or init a new one";
        wantedBy = [ "multi-user.target" ];
        after = [ "docker.service" ];
        requires = [ "docker.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = ''
            ${pkgs.bash}/bin/bash -c '
              set -euo pipefail

              if [[ -f /var/lib/docker/swarm/docker-state.json ]]; then
                echo "Already in Swarm – skipping."
                exit 0
              fi

              echo "Trying to join Swarm on ${managerAddr}"
              token=$(${pkgs.docker}/bin/ssh ${managerAddr} docker swarm join-token worker -q) 2>/dev/null || true)

              if [[ -n "$token" ]]; then
                ${pkgs.docker}/bin/docker swarm join --token "$token" ${managerAddr}:${managerPort} && exit 0
              fi

              echo "No reachable Swarm – initializing."
              ${pkgs.docker}/bin/docker swarm init --advertise-addr ${config.networking.hostName}

            '
          '';
          User = "root";
        };
      };
      virtualisation.docker.enable = true;
    }

