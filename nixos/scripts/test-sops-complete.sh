#!/usr/bin/env bash
# /etc/nixos/scripts/test-sops-complete.sh

set -euo pipefail

cd /etc/nixos/secrets

echo "🔍 Test complet de sops avec age"

# Configuration de la clé age
export SOPS_AGE_KEY_FILE="/etc/nixos/secrets/keys/age-keys.txt"
echo "🔑 Clé age: $SOPS_AGE_KEY_FILE"

# Vérification de l'existence de la clé
if [ ! -f "$SOPS_AGE_KEY_FILE" ]; then
    echo "❌ Clé age non trouvée"
    exit 1
fi

# Test de chiffrement/déchiffrement
echo "🧪 Test de cycle complet chiffrement/déchiffrement..."

cat > ceph/test-complete.yaml << EOF
test_fsid: "$(uuidgen)"
test_key: "AQBWlyBh+RJeFRAA$(openssl rand -base64 16)=="
timestamp: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

echo "📝 Fichier de test créé"
cat ceph/test-complete.yaml

echo "🔐 Chiffrement..."
if sops -e ceph/test-complete.yaml > ceph/test-complete-encrypted.yaml; then
    echo "✅ Chiffrement réussi"
else
    echo "❌ Échec du chiffrement"
    exit 1
fi

echo "🔓 Déchiffrement..."
if sops -d ceph/test-complete-encrypted.yaml > ceph/test-complete-decrypted.yaml; then
    echo "✅ Déchiffrement réussi"
    echo "📋 Contenu déchiffré:"
    cat ceph/test-complete-decrypted.yaml
else
    echo "❌ Échec du déchiffrement"
    exit 1
fi

# Vérification que le contenu est identique
if diff ceph/test-complete.yaml ceph/test-complete-decrypted.yaml > /dev/null; then
    echo "✅ Cycle complet réussi - les fichiers sont identiques"
else
    echo "❌ Différence entre l'original et le déchiffré"
    diff ceph/test-complete.yaml ceph/test-complete-decrypted.yaml
fi

# Nettoyage
rm -f ceph/test-complete.yaml ceph/test-complete-encrypted.yaml ceph/test-complete-decrypted.yaml

echo "🎉 sops fonctionne parfaitement !"
echo ""
echo "🚀 Prêt pour l'initialisation des secrets Ceph"
echo "Commande: SOPS_AGE_KEY_FILE=$SOPS_AGE_KEY_FILE ../scripts/init-ceph-secrets.sh"
EOF

