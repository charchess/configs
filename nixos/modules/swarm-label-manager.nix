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
      coreutils # coreutils contient tr, gawk, etc.
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
        # CORRECTION: Ajouter pkgs.coreutils/bin au PATH
        Environment = "PATH=${pkgs.docker}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:$PATH";
      };
      # Le script principal.
      script = ''
        set -e
        set -x # Active le mode de débogage pour afficher chaque commande exécutée

        echo "Début du script docker-swarm-label-manager."

        # Check if Docker is available
        if ! command -v docker &> /dev/null; then
          echo "ERREUR: Commande Docker introuvable. Sortie."
          exit 1
        fi
        echo "Docker est disponible."

        # --- VÉRIFICATION DU RÔLE ---
        echo "Vérification du rôle du nœud dans le Swarm..."
        IS_MANAGER=$(docker info --format '{{.Swarm.ControlAvailable}}')
        # Fix: Escape curly braces for Nix to prevent syntax error
        echo "Résultat de 'docker info --format '\{\{.Swarm.ControlAvailable\}\}': $IS_MANAGER"
        if [ "$IS_MANAGER" != "true" ]; then
          echo "Ce nœud n'est PAS un Swarm Manager. Le script se termine sans action."
          exit 0
        fi
        echo "Ce nœud est un Swarm Manager. Poursuite de la labellisation."

        echo "--- Exécution de la labellisation des nœuds Swarm depuis le manager ---"

        # Boucler sur chaque nœud actif dans le Swarm.
        NODES_Q=$(docker node ls -q)
        if [ -z "$NODES_Q" ]; then
          echo "Aucun nœud trouvé dans le Swarm. Fin de la labellisation."
          exit 0
        fi
        echo "Nœuds trouvés dans le Swarm: $NODES_Q"

        for node_id in $NODES_Q; do
          echo "--- Traitement du nœud ID: $node_id ---"
          # Au lieu du nom d'hôte, récupérez l'adresse IP du nœud.
          NODE_IP=$(docker node inspect "$node_id" --format '{{.Status.Addr}}')
          HOSTNAME=$(docker node inspect "$node_id" --format '{{.Description.Hostname}}') # Garder le hostname pour l'affichage si nécessaire
          echo "Nœud traité: $HOSTNAME (IP: $NODE_IP)"

          # Interroger l'API du nœud pour obtenir les labels désirés en utilisant l'IP.
          CURL_TARGET="http://$NODE_IP:${toString reporterPort}"
          echo "Tentative de récupération des labels désirés via curl de $CURL_TARGET"
          # -sS : Silencieux, mais montre les erreurs.
          # --connect-timeout 5 : N'attend pas plus de 5 secondes pour la connexion.
          CURL_OUTPUT=$(curl -sS --connect-timeout 5 "$CURL_TARGET")
          CURL_EXIT_CODE=$?

          if [ "$CURL_EXIT_CODE" -ne 0 ]; then
            echo "ERREUR CURL: La commande curl a échoué avec le code $CURL_EXIT_CODE."
            echo "Output Curl (si disponible) : '$CURL_OUTPUT'"
            echo "Warning: Échec de la récupération du statut depuis $HOSTNAME ($NODE_IP), saut."
            continue
          fi

          echo "Réponse Curl reçue. Tentative d'extraction et de validation du JSON des labels."
          # Nettoyer les retours chariot et valider/compacter le JSON avec jq -c .
          # Utiliser jq -e pour valider.
          DESIRED_LABELS_JSON=$(echo "$CURL_OUTPUT" | tr -d '\r' | jq -c . 2>/dev/null)
          JQ_EXIT_CODE=$? # Ce code est pour la commande `jq -c .` de parsing

          if [ "$JQ_EXIT_CODE" -ne 0 ]; then
            echo "ERREUR: La commande 'jq -c .' a échoué (code $JQ_EXIT_CODE)."
            echo "La réponse de $CURL_TARGET n'est pas un JSON valide ou est vide."
            echo "Réponse originale (CURL_OUTPUT) : '$CURL_OUTPUT'"
            echo "Warning: Échec du traitement du JSON pour $HOSTNAME ($NODE_IP), saut."
            continue
          fi

          if [ -z "$DESIRED_LABELS_JSON" ]; then
            echo "Avertissement: Le JSON des labels désirés est vide après traitement jq."
            echo "Output Curl original : '$CURL_OUTPUT'"
            echo "Warning: Échec de la récupération du statut (JSON vide) depuis $HOSTNAME ($NODE_IP), saut."
            continue
          fi
          echo "Labels désirés (JSON compacté) : $DESIRED_LABELS_JSON"

          # Obtenir les labels actuels du nœud depuis Swarm.
          CURRENT_LABELS_JSON=$(docker node inspect "$node_id" --format '{{json .Spec.Labels}}' | jq '. // {}')
          echo "Labels actuels Swarm (JSON) : $CURRENT_LABELS_JSON"

          # Comparer les deux objets JSON. Si différents, on met à jour.
          echo "Comparaison des labels désirés et actuels..."
          # CORRECTION: Utiliser `jq -e` pour que `jq` renvoie un code d'erreur non nul si la comparaison est fausse.
          if ! jq -e -n --argjson desired "$DESIRED_LABELS_JSON" --argjson current "$CURRENT_LABELS_JSON" '$desired == $current' >/dev/null 2>&1; then
            echo "Décalage de labels détecté pour $HOSTNAME ($NODE_IP). Application de la nouvelle configuration."

            UPDATE_CMD="docker node update"

            # Ajouter/Mettre à jour les labels désirés.
            echo "Ajout/Mise à jour des labels désirés..."
            for key in $(echo "$DESIRED_LABELS_JSON" | jq -r 'keys[]'); do
              value=$(echo "$DESIRED_LABELS_JSON" | jq -r --arg k "$key" '.[$k]')
              echo "  - Ajout/Mise à jour : $key=$value"
              UPDATE_CMD="$UPDATE_CMD --label-add \"$key=$value\""
            done

            # Retirer les anciens labels qui ne sont plus dans la config désirée.
            echo "Vérification des labels à retirer..."
            for key in $(echo "$CURRENT_LABELS_JSON" | jq -r 'keys[]'); do
              if ! echo "$DESIRED_LABELS_JSON" | jq -e --arg k "$key" '.[$k]' >/dev/null; then
                echo "  - Retrait : $key"
                UPDATE_CMD="$UPDATE_CMD --label-rm \"$key\""
              fi
            done

            UPDATE_CMD="$UPDATE_CMD $node_id" # Utiliser le node_id pour la mise à jour, c'est plus robuste

            echo "Commande d'exécution préparée: $UPDATE_CMD"
            eval "$UPDATE_CMD"
            if [ $? -eq 0 ]; then
              echo "Mise à jour des labels pour $HOSTNAME réussie."
            else
              echo "ERREUR: Échec de la mise à jour des labels pour $HOSTNAME."
            fi
          else
            echo "Labels pour $HOSTNAME ($NODE_IP) déjà à jour. Aucune action nécessaire."
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


