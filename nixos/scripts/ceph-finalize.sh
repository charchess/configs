#!/usr/bin/env bash

echo "🔍 Finalisation de la configuration Ceph"

# Attendre que le monitor soit prêt
sleep 5

# Test de base
echo "📡 Test de connectivité monitor..."
if timeout 10 ceph mon stat; then
    echo "✅ Monitor accessible"
else
    echo "❌ Monitor non accessible"
    
    # Debug
    echo "🔍 Debug monitor:"
    sudo journalctl -u ceph-mon-jade --no-pager -n 10
    
    echo "🔍 Processus ceph:"
    ps aux | grep ceph
    
    echo "🔍 Ports ouverts:"
    ss -tlnp | grep 6789
fi

# Vérification des keyrings
echo "🔑 Vérification des keyrings..."
ls -la /etc/ceph/ceph.client.admin.keyring
ls -la /var/lib/ceph/bootstrap-osd/ceph.keyring

# Test de santé du cluster
echo "💓 Test de santé du cluster..."
timeout 15 ceph health detail || echo "Timeout ou erreur de santé"

echo "🎯 Finalisation terminée"
