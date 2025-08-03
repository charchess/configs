#!/usr/bin/env bash
# /etc/nixos/scripts/fix-sops-config.sh

set -euo pipefail

cd /etc/nixos/secrets

echo "🔧 Correction du fichier .sops.yaml"

# Sauvegarde
cp .sops.yaml .sops.yaml.backup

# Récupération de la clé age
if [ -f "keys/age-keys.txt" ]; then
    AGE_KEY=$(grep "public key:" keys/age-keys.txt | cut -d' ' -f4)
    echo "🔑 Clé age récupérée: $AGE_KEY"
else
    echo "❌ Fichier de clé age non trouvé"
    exit 1
fi

# Récupération de la clé SSH de jade (machine locale)
if [ -f "/etc/ssh/ssh_host_ed25519_key.pub" ]; then
    JADE_SSH=$(cat /etc/ssh/ssh_host_ed25519_key.pub)
    echo "🔑 Clé SSH jade récupérée"
else
    echo "❌ Clé SSH de jade non trouvée"
    exit 1
fi

# Tentative de récupération des autres clés SSH (optionnel pour l'instant)
EMY_SSH=""
RUBY_SSH=""

if ssh-keyscan -t ed25519 192.168.111.65 > /tmp/emy.pub 2>/dev/null; then
    EMY_SSH=$(cat /tmp/emy.pub)
    echo "🔑 Clé SSH emy récupérée"
    rm -f /tmp/emy.pub
fi

if ssh-keyscan -t ed25519 192.168.111.66 > /tmp/ruby.pub 2>/dev/null; then
    RUBY_SSH=$(cat /tmp/ruby.pub)
    echo "🔑 Clé SSH ruby récupérée"
    rm -f /tmp/ruby.pub
fi

# Création du nouveau .sops.yaml
echo "📝 Création du nouveau .sops.yaml..."

cat > .sops.yaml << EOF
keys:
  # Clé age maître
  - &admin_age $AGE_KEY
  
  # Clé SSH de jade
  - &jade_ssh $JADE_SSH
EOF

# Ajout des autres clés si disponibles
if [ -n "$EMY_SSH" ]; then
    echo "  - &emy_ssh $EMY_SSH" >> .sops.yaml
fi

if [ -n "$RUBY_SSH" ]; then
    echo "  - &ruby_ssh $RUBY_SSH" >> .sops.yaml
fi

# Ajout des règles de création
cat >> .sops.yaml << EOF

creation_rules:
  # Secrets Ceph
  - path_regex: ceph/.*\.yaml$
    key_groups:
    - age:
        - *admin_age
      ssh:
        - *jade_ssh
EOF

# Ajout des autres machines aux règles si leurs clés sont disponibles
if [ -n "$EMY_SSH" ]; then
    sed -i '/- \*jade_ssh/a\        - *emy_ssh' .sops.yaml
fi

if [ -n "$RUBY_SSH" ]; then
    sed -i '/- \*emy_ssh/a\        - *ruby_ssh' .sops.yaml 2>/dev/null || sed -i '/- \*jade_ssh/a\        - *ruby_ssh' .sops.yaml
fi

echo "✅ Nouveau .sops.yaml créé"
echo ""
echo "📋 Contenu:"
cat .sops.yaml
echo ""

# Test de validation YAML
if python3 -c "import yaml; yaml.safe_load(open('.sops.yaml'))" 2>/dev/null; then
    echo "✅ Format YAML valide"
else
    echo "❌ Format YAML invalide"
    echo "Restauration de la sauvegarde..."
    mv .sops.yaml.backup .sops.yaml
    exit 1
fi

# Test de sops
echo "🧪 Test de sops..."
echo 'test: "hello world"' > /tmp/test-sops.yaml

if sops -e /tmp/test-sops.yaml > /tmp/test-encrypted.yaml 2>/dev/null; then
    echo "✅ Configuration sops fonctionnelle"
    rm -f /tmp/test-sops.yaml /tmp/test-encrypted.yaml
else
    echo "❌ Problème avec la configuration sops"
    cat .sops.yaml
    exit 1
fi

echo "🎉 Configuration sops corrigée et fonctionnelle!"
EOF

# Rendez le script exécutable
chmod +x /etc/nixos/scripts/fix-sops-config.sh


