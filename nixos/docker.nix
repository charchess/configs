{ config, pkgs, ... }:

{
  # configuration de docker
  virtualisation.docker.enable = true;
  
  networking.firewall = {
    allowedUDPPorts = [ 794 4789 7946 ];
    allowedTCPPorts = [ 80 443 794 2377 7946 ];
  };

  # jonction au swarm si pas deja fait 
  systemd.services.docker-swarm-join = {
    description = "Join Docker Swarm if not already a member";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];

    # On retire la condition de serviceConfig, car elle est sujette à une condition de course.
    # serviceConfig.ConditionPathExists = "!/var/lib/docker/swarm"; 

    serviceConfig.Type = "oneshot";
  	
    # Le script à exécuter
    script = ''
      set -e # Arrête le script si une commande échoue

      # On vérifie directement auprès de Docker s'il est actif dans un swarm.
      # 'grep -q' est silencieux et renvoie un code de succès (0) si le texte est trouvé.
      # Le '!' inverse le code de retour. La condition est donc vraie si le noeud N'EST PAS actif.
      if ! ${pkgs.docker}/bin/docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo "Node is not in a swarm, attempting to join..."
        # Remplacez l'IP et le port par ceux de votre manager
        ${pkgs.docker}/bin/docker swarm join --token SWMTKN-1-0ilvdu4vv7rlzrtojz27nrj278lobm7kmr6d49fvh6armeim8x-8jrixhyalzgdmwr3jl8h7347p 192.168.200.66:2377
      else
        echo "Node is already a member of a swarm. Skipping join."
      fi
    '';
  };
}