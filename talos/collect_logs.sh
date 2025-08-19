#!/bin/bash
# collect-k8s-debug.sh
# Collecte complète des infos de debug pour un cluster Kubernetes

set -euo pipefail

# Configuration
KUBECONFIG="$HOME/configs/talos/kubeconfig"
OUTPUT_DIR="$HOME/debug-k8s-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "📁 Collecte des informations dans $OUTPUT_DIR..."

# 1. Ressources globales
echo "🔍 Collecte des ressources globales..."
kubectl --kubeconfig="$KUBECONFIG" get all -A -o wide > all-resources.txt
kubectl --kubeconfig="$KUBECONFIG" get nodes -o wide > nodes.txt
kubectl --kubeconfig="$KUBECONFIG" get events --all-namespaces --sort-by='.lastTimestamp' > events.txt

# 2. Descriptifs détaillés
echo "🧾 Collecte des descriptifs..."
kubectl --kubeconfig="$KUBECONFIG" describe nodes > nodes-describe.txt
kubectl --kubeconfig="$KUBECONFIG" describe pods -A > all-pods-describe.txt

# 3. Logs des pods problématiques
echo "📜 Collecte des logs des pods en échec..."

# Hubble
kubectl --kubeconfig="$KUBECONFIG" logs -n kube-system deployment/hubble-relay --tail=500 > hubble-relay.log || true
kubectl --kubeconfig="$KUBECONFIG" logs -n kube-system deployment/hubble-ui --tail=500 > hubble-ui.log || true

# Dashboard
kubectl --kubeconfig="$KUBECONFIG" logs -n kubernetes-dashboard deployment/kubernetes-dashboard --tail=500 > dashboard.log || true
kubectl --kubeconfig="$KUBECONFIG" logs -n kubernetes-dashboard deployment/dashboard-metrics-scraper --tail=500 > dashboard-scraper.log || true

# Traefik
kubectl --kubeconfig="$KUBECONFIG" logs -n traefik deployment/traefik --tail=500 > traefik.log || true

# MetalLB
kubectl --kubeconfig="$KUBECONFIG" logs -n metallb-system deployment/controller --tail=500 > metallb-controller.log || true
kubectl --kubeconfig="$KUBECONFIG" logs -n metallb-system daemonset/speaker --tail=500 > metallb-speaker.log || true

# Metrics-server
kubectl --kubeconfig="$KUBECONFIG" describe pod -n kube-system -l k8s-app=metrics-server > metrics-server-describe.txt
kubectl --kubeconfig="$KUBECONFIG" logs -n kube-system deployment/metrics-server --tail=500 > metrics-server.log || true

# 4. ConfigMaps et CRDs utiles
echo "⚙️ Collecte des ConfigMaps et CRDs..."

# Cilium
kubectl --kubeconfig="$KUBECONFIG" get cm -n kube-system -o yaml hubble-relay-config > cm-hubble-relay.yaml || true
kubectl --kubeconfig="$KUBECONFIG" get cm -n kube-system -o yaml hubble-ui-config > cm-hubble-ui.yaml || true

# MetalLB
kubectl --kubeconfig="$KUBECONFIG" get ipaddresspool -n metallb-system -o yaml > metallb-ipaddresspools.yaml || true
kubectl --kubeconfig="$KUBECONFIG" get l2advertisement -n metallb-system -o yaml > metallb-l2advertisements.yaml || true

# Traefik
kubectl --kubeconfig="$KUBECONFIG" get ingressroute -A -o yaml > traefik-ingressroutes.yaml || true

# 5. Infos système (si exécuté localement)
if command -v talosctl &> /dev/null; then
    echo "🖥️ Collecte des infos Talos..."
    talosctl --talosconfig ~/.talos/config get members > talos-members.txt || true
    talosctl --talosconfig ~/.talos/config stats > talos-stats.txt || true
fi

# 6. Compresser le tout
echo "📦 Compression des résultats..."
tar -czf "../$(basename "$OUTPUT_DIR").tar.gz" .
cd ..
rm -rf "$OUTPUT_DIR"

echo "✅ Collecte terminée. Archive : $(basename "$OUTPUT_DIR").tar.gz"
