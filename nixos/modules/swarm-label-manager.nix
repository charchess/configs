# /etc/nixos/swarm-label-manager.nix
#
# Module NixOS pour le Labelliseur Centralisé.
# Ce module est conçu pour être déployé sur TOUS les nœuds.
# Il contient une logique pour ne s'exécuter que si le nœud est un manager Swarm.

{ lib, config, pkgs, ... }:

let
  # Le port sur lequel les reporters écoutent.
  reporterPort = 9101;
in
{
  config = {
    # On garantit la présence des dépendances sur tous les nœuds
    # où ce module est importé.
    environment.systemPackages = with pkgs; [
      docker
      curl
      jq
      coreutils
      gawk
    ];

    # Le service systemd qui gère la labellisation.
    systemd.services.docker-swarm-label-manager = {
      description = "Central Swarm Label Manager (runs only on managers)";
      
      # Dépendances : a besoin du réseau et du daemon Docker pour fonctionner.
      after = [ "network-online.target" "docker.service" ];
      requires = [ "docker.service" ];

      # Le script principal.
      script = ''
        set -e
        
       # Check if Docker is available
        if ! command -v docker &> /dev/null; then
          echo "Docker command not found. Exiting."
          exit 1
        fi

        # --- VÉRIFICATION DU RÔLE ---
        # C'est la logique la plus importante.
        # 'docker info' nous dit si le nœud est un manager.
        # Si ce n'est pas le cas, on quitte le script avec succès (code 0), sans rien faire.
        IS_MANAGER=$(docker info --format '{{.Swarm.ControlAvailable}}')
        if [ "$IS_MANAGER" != "true" ]; then
          echo "This node is not a Swarm Manager. Skipping labeling task."
          exit 0
        fi

        # Si on arrive ici, c'est que le nœud est bien un manager.
        echo "--- Running Swarm-wide node labeling from manager ---"

        # Boucler sur chaque nœud actif dans le Swarm.
        for node_id in $(docker node ls -q); do
          HOSTNAME=$(docker node inspect "$node_id" --format '{{.Description.Hostname}}')
          echo "--- Processing node: $HOSTNAME ---"
          
          # Interroger l'API du nœud pour obtenir les labels désirés.
          # -sS : Silencieux, mais montre les erreurs.
          # --connect-timeout 5 : N'attend pas plus de 5 secondes pour la connexion.
          # sed '1,/^$/d' : Supprime les en-têtes HTTP pour ne garder que le corps JSON.
          CURL_OUTPUT=$(curl -sS --connect-timeout 5 http://$HOSTNAME:${toString reporterPort})
	  DESIRED_LABELS_JSON=$(echo "$CURL_OUTPUT" | gawk 'BEGIN{RS="\r\n\r\n"} NR==2{print}')  
        
          if [ -z "$DESIRED_LABELS_JSON" ]; then
            echo "Warning: Failed to get status from $HOSTNAME, skipping."
            # On ne sort pas en erreur, on continue avec les autres nœuds.
            continue
          fi

          # Obtenir les labels actuels du nœud depuis Swarm.
          CURRENT_LABELS_JSON=$(docker node inspect "$HOSTNAME" --format '{{json .Spec.Labels}}' | jq '. // {}')
          
          # Comparer les deux objets JSON. Si différents, on met à jour.
          if ! jq -n --argjson desired "$DESIRED_LABELS_JSON" --argjson current "$CURRENT_LABELS_JSON" '$desired == $current' 2>/dev/null; then
            echo "Label mismatch detected for $HOSTNAME. Applying new configuration."

            UPDATE_CMD="docker node update"
            
            # Ajouter/Mettre à jour les labels désirés.
            for key in $(echo "$DESIRED_LABELS_JSON" | jq -r 'keys[]'); do
              value=$(echo "$DESIRED_LABELS_JSON" | jq -r --arg k "$key" '.[$k]')
              UPDATE_CMD="$UPDATE_CMD --label-add \"$key=$value\""
            done
            
            # Retirer les anciens labels qui ne sont plus dans la config désirée.
            for key in $(echo "$CURRENT_LABELS_JSON" | jq -r 'keys[]'); do
              if ! echo "$DESIRED_LABELS_JSON" | jq -e --arg k "$key" '.[$k]' >/dev/null; then
                UPDATE_CMD="$UPDATE_CMD --label-rm \"$key\""
              fi
            done
            
            UPDATE_CMD="$UPDATE_CMD $HOSTNAME"
            
            echo "Executing: $UPDATE_CMD"
            eval $UPDATE_CMD
          else
            echo "Labels for $HOSTNAME are already up to date."
          fi
        done
        echo "--- Swarm-wide labeling finished ---"
      '';
    };

    # Le timer qui déclenche périodiquement le service.
    systemd.timers.docker-swarm-label-manager = {
      description = "Timer to periodically run the Swarm label manager";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "docker-swarm-label-manager.service";
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
      };
    };
  };
}