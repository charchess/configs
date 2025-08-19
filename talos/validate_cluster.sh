#!/bin/bash

# ==============================================================================
# Script de Validation Fonctionnelle de Cluster Kubernetes
#
# Ce script teste les fonctionnalités des composants critiques, pas seulement
# leur état de fonctionnement.
# ==============================================================================

# --- Options ---
set -o pipefail # Fait échouer une commande si une partie d'un pipeline échoue

# --- Couleurs et Compteurs ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
CHECKS_PASSED=0
CHECKS_FAILED=0

# --- Fonction d'aide ---
check_result() {
  if [ "$1" -eq 0 ]; then
    echo -e "${GREEN}  [OK]   ${2}${NC}"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
  else
    echo -e "${RED}  [ECHEC] ${2}${NC}"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
  fi
}

echo -e "${YELLOW}--- Début de la validation fonctionnelle du cluster ---${NC}"

# --- 1. Validation Fonctionnelle de Cilium ---
echo -e "\n${YELLOW}[1/4] Validation Fonctionnelle de Cilium...${NC}"

CILIUM_AGENT_POD=$(kubectl get pods -n kube-system -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$CILIUM_AGENT_POD" ]; then
    check_result 1 "Impossible de trouver un pod agent Cilium."
else
    # Test plus pertinent : on vérifie que les contrôleurs sont 'healthy'
    kubectl exec -n kube-system "$CILIUM_AGENT_POD" -- cilium status | grep -q "Controller Status:       [1-9][0-9]*/[1-9][0-9]* healthy"
    check_result $? "Les contrôleurs internes de l'agent Cilium sont 'healthy'."

    # On vérifie la connectivité Hubble
    kubectl exec -n kube-system "$CILIUM_AGENT_POD" -- hubble status | grep -q "Flows"
    check_result $? "Hubble est connecté et observe les flux."
fi

# Le test le plus important pour Hubble Relay : est-il Ready ?
kubectl wait --for=condition=Ready pod -l k8s-app=hubble-relay -n kube-system --timeout=60s &>/dev/null
check_result $? "Hubble Relay est Ready (communication avec l'agent OK)."



# --- 2. Validation Fonctionnelle de MetalLB ---
echo -e "\n${YELLOW}[2/4] Validation Fonctionnelle de MetalLB...${NC}"

# Le test fonctionnel de MetalLB est de vérifier qu'il a bien assigné une IP à un service
TRAEFIK_IP=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$TRAEFIK_IP" ]; then
  check_result 0 "MetalLB a bien assigné une IP externe ($TRAEFIK_IP) au service Traefik."
else
  check_result 1 "MetalLB N'A PAS assigné d'IP externe au service Traefik."
fi

# --- 3. Validation Fonctionnelle de Traefik ---
echo -e "\n${YELLOW}[3/4] Validation Fonctionnelle de Traefik...${NC}"

TRAEFIK_POD=$(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$TRAEFIK_POD" ]; then
    check_result 1 "Impossible de trouver le pod Traefik."
else
    # Un bon test fonctionnel est de vérifier l'absence d'erreurs dans les logs
    if ! kubectl logs --since=10m -n traefik "$TRAEFIK_POD" | grep -iE 'level=error|ERR'; then
        check_result 0 "Les logs récents de Traefik sont exempts d'erreurs critiques."
    else
        check_result 1 "Les logs récents de Traefik contiennent des erreurs critiques."
    fi
fi

# --- 4. Validation Fonctionnelle des URLs (Test de bout en bout) ---
echo -e "\n${YELLOW}[4/4] Validation de l'accès externe via Traefik...${NC}"

if [ -z "$TRAEFIK_IP" ]; then
  echo -e "${RED}  [SKIP] Impossible de tester les URLs sans l'IP de Traefik.${NC}"
  CHECKS_FAILED=$((CHECKS_FAILED + 3))
else
  # Test de l'URL du dashboard Traefik, on attend un code 200 OK
  curl --silent --fail --connect-timeout 5 -H "Host: traefik.truxonline.com" http://"$TRAEFIK_IP"/dashboard/ &>/dev/null
  check_result $? "Dashboard Traefik : Réponse 200 OK via l'IngressRoute."

  # Test de l'URL du dashboard Kubernetes, on attend un code 200 OK
  curl --silent --fail --connect-timeout 5 -H "Host: dashboard.truxonline.com" http://"$TRAEFIK_IP"/ &>/dev/null
  check_result $? "Kubernetes Dashboard : Réponse 200 OK via l'IngressRoute."

  # Test de l'URL de Hubble UI, on attend un code 200 OK
  curl --silent --fail --connect-timeout 5 -H "Host: hubble.truxonline.com" http://"$TRAEFIK_IP"/ &>/dev/null
  check_result $? "Hubble UI : Réponse 200 OK via l'IngressRoute."
fi

# --- Résumé ---
echo -e "\n${YELLOW}--- Validation terminée ---${NC}"
echo -e "${GREEN}Tests fonctionnels passés : $CHECKS_PASSED${NC}"
echo -e "${RED}Tests fonctionnels échoués : $CHECKS_FAILED${NC}"

if [ "$CHECKS_FAILED" -ne 0 ]; then
  echo -e "${YELLOW}\nUn ou plusieurs tests fonctionnels ont échoué. Veuillez vérifier les logs ci-dessus.${NC}"
  exit 1
fi

echo -e "${GREEN}\nFélicitations ! Tous les tests fonctionnels sont passés avec succès.${NC}"
exit 0