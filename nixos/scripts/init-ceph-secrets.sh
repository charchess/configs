#!/usr/bin/env bash
# /etc/nixos/scripts/init-ceph-secrets.sh (version avec gestion des clés)
export SOPS_AGE_KEY_FILE="/etc/nixos/secrets/keys/age-keys.txt"

set -euo pipefail

SECRETS_BASE="/etc/nixos/secrets"
SECRETS_DIR="$SECRETS_BASE/ceph"
AGE_KEY_FILE="$SECRETS_BASE/keys/age-keys.txt"

echo "🔑 Initialisation des secrets Ceph avec sops-nix"

# Changement vers le répertoire de base des secrets
cd "$SECRETS_BASE"
echo "📁 Répertoire de travail: $(pwd)"

# Vérification des prérequis
if ! command -v sops &> /dev/null; then
    echo "❌ sops n'est pas installé"
    exit 1
fi

if [ ! -f ".sops.yaml" ]; then
    echo "❌ Fichier .sops.yaml manquant"
    exit 1
fi

if [ ! -f "$AGE_KEY_FILE" ]; then
    echo "❌ Clé age privée manquante: $AGE_KEY_FILE"
    exit 1
fi

echo "✅ Configuration sops trouvée"

# Configuration de la clé age pour sops
export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"
echo "🔑 Utilisation de la clé age: $SOPS_AGE_KEY_FILE"

# Création de la structure
mkdir -p ceph

# Génération du FSID
FSID=$(uuidgen)
echo "📝 FSID généré: $FSID"

# Génération des clés Ceph
generate_ceph_key() {
    python3 -c "
import base64
import os
key = base64.b64encode(os.urandom(16)).decode('ascii')
print(f'AQBWlyBh+RJeFRAA{key}==')
"
}

ADMIN_KEY=$(generate_ceph_key)
MON_KEY=$(generate_ceph_key)
BOOTSTRAP_OSD_KEY=$(generate_ceph_key)
BOOTSTRAP_MDS_KEY=$(generate_ceph_key)
BOOTSTRAP_RGW_KEY=$(generate_ceph_key)

echo "🔐 Clés Ceph générées"

# Création des fichiers temporaires
cat > ceph/cluster-temp.yaml << EOF
fsid: "$FSID"
admin_key: "$ADMIN_KEY"
bootstrap_osd_key: "$BOOTSTRAP_OSD_KEY"
bootstrap_mds_key: "$BOOTSTRAP_MDS_KEY"
bootstrap_rgw_key: "$BOOTSTRAP_RGW_KEY"
EOF

cat > ceph/monitors-temp.yaml << EOF
mon_key: "$MON_KEY"
jade_mon_key: "$MON_KEY"
emy_mon_key: "$MON_KEY"
ruby_mon_key: "$MON_KEY"
EOF

# Chiffrement avec sops
echo "🔐 Chiffrement des secrets..."

if sops -e ceph/cluster-temp.yaml > ceph/cluster.yaml; then
    echo "✅ cluster.yaml chiffré"
    rm -f ceph/cluster-temp.yaml
else
    echo "❌ Échec du chiffrement cluster.yaml"
    exit 1
fi

if sops -e ceph/monitors-temp.yaml > ceph/monitors.yaml; then
    echo "✅ monitors.yaml chiffré"
    rm -f ceph/monitors-temp.yaml
else
    echo "❌ Échec du chiffrement monitors.yaml"
    exit 1
fi

echo "🎉 Initialisation des secrets terminée!"
echo "📁 Secrets disponibles dans: $SECRETS_DIR"
echo ""

# Test de déchiffrement
echo "🔍 Test de déchiffrement..."
if sops -d ceph/cluster.yaml > /dev/null 2>&1; then
    echo "✅ Test de déchiffrement cluster.yaml réussi"
    echo "🔍 Aperçu du FSID:"
    sops -d ceph/cluster.yaml | grep fsid
else
    echo "❌ Problème de déchiffrement cluster.yaml"
fi

if sops -d ceph/monitors.yaml > /dev/null 2>&1; then
    echo "✅ Test de déchiffrement monitors.yaml réussi"
else
    echo "❌ Problème de déchiffrement monitors.yaml"
fi

echo ""
echo "📋 Commandes utiles:"
echo "# Voir tous les secrets cluster:"
echo "SOPS_AGE_KEY_FILE=$AGE_KEY_FILE sops -d ceph/cluster.yaml"
echo ""
echo "# Voir tous les secrets monitors:"
echo "SOPS_AGE_KEY_FILE=$AGE_KEY_FILE sops -d ceph/monitors.yaml"
EOF

