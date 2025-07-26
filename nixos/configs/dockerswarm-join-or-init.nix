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

          echo "Trying to join Swarm on ${managerAddr}:${managerPort} ..."
          token=$(${pkgs.curl}/bin/curl -s --connect-timeout 3 \
                   http://${managerAddr}:${managerPort}/swarm/token/manager 2>/dev/null || true)

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

  # On expose l’agent sur 9001
  networking.firewall.allowedTCPPorts = [ 9001 ];

  systemd.services.portainer-agent = {
    description = "Portainer Agent (Swarm leader only)";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    # Le service ne tourne qu’une seule fois
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };

    script = ''
      set -euo pipefail

      # 1) Ne rien faire si ce nœud n’est PAS le leader
      if [[ "$(${pkgs.docker}/bin/docker node ls --filter role=manager --format '{{.Hostname}}' 2>/dev/null || true)" != *"${config.networking.hostName}"* ]]; then
        echo "Not Swarm leader – skipping agent."
        exit 0
      fi

      # 2) Ne rien faire si l’agent tourne déjà
      if ${pkgs.docker}/bin/docker service ls --filter name=portainer_agent --format '{{.Name}}' | grep -q portainer_agent; then
        echo "Portainer agent service already exists – skipping."
        exit 0
      fi

      # 3) Créer le réseau s’il n’existe pas
      ${pkgs.docker}/bin/docker network create --driver overlay ${networkName} 2>/dev/null || true

      # 4) Lancer l’agent global sur le Swarm
      ${pkgs.docker}/bin/docker service create \
        --name portainer_agent \
        --network ${networkName} \
        -p 9001:9001/tcp \
        --mode global \
        --constraint 'node.platform.os == linux' \
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
        --mount type=bind,src=/var/lib/docker/volumes,dst=/var/lib/docker/volumes \
        --mount type=bind,src=/,dst=/host \
        portainer/agent:${agentTag}
    '';
  };
}