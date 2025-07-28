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

      # Spécifiez les dépendances du service
      serviceConfig = {
        Environment = "PATH=${pkgs.docker}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:$PATH";
      };
      # Le script principal.
      script = ''
        set -e
        # set -x # Désactivé pour réduire la verbosité

        echo "--- Début du Central Swarm Label Manager ---"

        if ! command -v docker &> /dev/null; then
          echo "ERREUR: Commande Docker introuvable. Sortie."
          exit 1
        fi

        # --- VÉRIFICATION DU RÔLE ---
        IS_MANAGER=$(docker info --format '{{.Swarm.ControlAvailable}}')
        if [ "$IS_MANAGER" != "true" ]; then
          echo "Ce nœud n'est PAS un Swarm Manager. Le script se termine sans action."
          exit 0
        fi
        echo "Exécution en tant que Swarm Manager."

        NODES_Q=$(docker node ls -q)
        if [ -z "$NODES_Q" ]; then
          echo "Aucun nœud trouvé dans le Swarm. Fin de la labellisation."
          exit 0
        fi

        for node_id in $NODES_Q; do
          NODE_IP=$(docker node inspect "$node_id" --format '{{.Status.Addr}}')
          HOSTNAME=$(docker node inspect "$node_id" --format '{{.Description.Hostname}}')
          echo "--- Traitement du nœud: $HOSTNAME ($NODE_IP) ---"

          CURL_TARGET="http://$NODE_IP:${toString reporterPort}"
          CURL_OUTPUT=$(curl -sS --connect-timeout 5 "$CURL_TARGET")
          CURL_EXIT_CODE=$?

          if [ "$CURL_EXIT_CODE" -ne 0 ]; then
            echo "Avertissement: Échec de la récupération du statut depuis $HOSTNAME ($NODE_IP) (Code CURL: $CURL_EXIT_CODE). Saut."
            # echo "Output Curl : '$CURL_OUTPUT'" # Uncomment for more debug if needed
            continue
          fi

          DESIRED_LABELS_JSON=$(echo "$CURL_OUTPUT" | tr -d '\r' | jq -c . 2>/dev/null)
          JQ_EXIT_CODE=$?

          if [ "$JQ_EXIT_CODE" -ne 0 ]; then
            echo "ERREUR: La réponse de $CURL_TARGET n'est pas un JSON valide ou est vide après traitement jq (Code JQ: $JQ_EXIT_CODE). Saut."
            # echo "Réponse originale (CURL_OUTPUT) : '$CURL_OUTPUT'" # Uncomment for more debug if needed
            continue
          fi

          if [ -z "$DESIRED_LABELS_JSON" ]; then
            echo "Avertissement: Le JSON des labels désirés est vide depuis $HOSTNAME ($NODE_IP). Saut."
            continue
          fi
          # echo "Labels désirés (JSON compacté) : $DESIRED_LABELS_JSON" # Uncomment for more debug if needed

          CURRENT_LABELS_JSON=$(docker node inspect "$node_id" --format '{{json .Spec.Labels}}' | jq '. // {}')
          # echo "Labels actuels Swarm (JSON) : $CURRENT_LABELS_JSON" # Uncomment for more debug if needed

          if ! jq -e -n --argjson desired "$DESIRED_LABELS_JSON" --argjson current "$CURRENT_LABELS_JSON" '$desired == $current' >/dev/null 2>&1; then
            echo "Décalage de labels détecté pour $HOSTNAME. Application de la nouvelle configuration."

            UPDATE_CMD="docker node update"

            for key in $(echo "$DESIRED_LABELS_JSON" | jq -r 'keys[]'); do
              value=$(echo "$DESIRED_LABELS_JSON" | jq -r --arg k "$key" '.[$k]')
              UPDATE_CMD="$UPDATE_CMD --label-add \"$key=$value\""
            done

            for key in $(echo "$CURRENT_LABELS_JSON" | jq -r 'keys[]'); do
              if ! echo "$DESIRED_LABELS_JSON" | jq -e --arg k "$key" '.[$k]' >/dev/null; then
                UPDATE_CMD="$UPDATE_CMD --label-rm \"$key\""
              fi
            done

            UPDATE_CMD="$UPDATE_CMD $node_id"

            # echo "Executing: $UPDATE_CMD" # Uncomment for full command debug
            eval "$UPDATE_CMD"
            if [ $? -eq 0 ]; then
              echo "Mise à jour des labels pour $HOSTNAME réussie."
            else
              echo "ERREUR: Échec de la mise à jour des labels pour $HOSTNAME."
            fi
          else
            echo "Labels pour $HOSTNAME sont déjà à jour."
          fi
        done
        echo "--- Labellisation Swarm terminée ---"
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

