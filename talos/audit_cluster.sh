#!/bin/bash
# audit-k8s-filtered.sh
# Audit automatique des pods en anomalie sur ton cluster Talos
# Avec filtrage des logs pour n’afficher que les erreurs pertinentes

KUBECONFIG="./kubeconfig"

echo "=== Recherche des pods suspects ==="
PODS=$(kubectl --kubeconfig=$KUBECONFIG get pods -A \
  | grep -E "Error|Completed|CrashLoopBackOff|0/" \
  | awk '{print $1" "$2}')

if [ -z "$PODS" ]; then
  echo "✅ Aucun pod suspect trouvé."
  exit 0
fi

echo "$PODS" | while read NAMESPACE POD; do
  echo
  echo "=============================="
  echo "🔎 Pod: $POD (Namespace: $NAMESPACE)"
  echo "=============================="

  echo "--> Statut (condensé) :"
  kubectl --kubeconfig=$KUBECONFIG describe pod -n $NAMESPACE $POD \
    | egrep -i "State:|Reason:|Message:" | tail -n 10

  echo
  echo "--> Logs (filtrés sur erreurs) :"
  kubectl --kubeconfig=$KUBECONFIG logs -n $NAMESPACE $POD --tail=100 2>&1 \
    | egrep -i "error|fail|warning|refused|unavailable|timeout" \
    | tail -n 20

  echo
  echo "--> Events récents :"
  kubectl --kubeconfig=$KUBECONFIG get events -n $NAMESPACE \
    --sort-by=.metadata.creationTimestamp \
    | grep $POD | tail -n 5
done