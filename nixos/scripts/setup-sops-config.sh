#!/usr/bin/env bash
# /etc/nixos/scripts/setup-sops-config.sh

set -euo pipefail

SECRETS_DIR="/etc/nixos/secrets"
KEYS_DIR="$SECRETS_DIR/keys"

echo "🔑 Configuration automatique de sops pour Ceph"

# Création de la structure
mkdir -p "$KEYS_DIR/hosts"
cd "$SECRETS_DIR"

# Fonction pour extraire la clé SSH d'un host
extract_ssh_key() {
    local host=$1
    local ip=$2
    local keyfile="$KEYS_DIR/hosts/${host}.pub"
    
    echo "📡 Récupération de la clé SSH de $host ($ip)..."
    
    if ssh-keyscan -t ed25519 "$ip" > "$keyfile" 2>/dev/null; then
        echo "✅ Clé SSH de $host récupérée"
        cat "$keyfile"
    else
        echo "❌ Échec de récupération de la clé SSH de $host"
        echo "💡 Essayez manuellement: ssh-keyscan -t ed25519 $ip"
        return 1
    fi
}

# Récupération des clés SSH
echo "🔍 Récupération des clés SSH des hosts..."
extract_ssh_key "jade" "192.168.111.63" || true
extract_ssh_key "emy" "192.168.111.65" || true  
extract_ssh_key "ruby" "192.168.111.66" || true

# Génération d'une clé age si elle n'existe pas
if [ ! -f "$KEYS_DIR/age-keys.txt" ]; then
    echo "🔐 Génération d'une clé age maître..."
    age-keygen > "$KEYS_DIR/age-keys.txt"
    echo "✅ Clé age générée: $KEYS_DIR/age-keys.txt"
fi

# Extraction de la clé publique age
AGE_PUBLIC_KEY=$(grep "public key:" "$KEYS_DIR/age-keys.txt" | cut -d' ' -f4)
echo "🔑 Clé age publique: $AGE_PUBLIC_KEY"

# Extraction des clés SSH
echo "📋 Extraction des clés SSH..."
JADE_SSH=""
EMY_SSH=""
RUBY_SSH=""

if [ -f "$KEYS_DIR/hosts/jade.pub" ]; then
    JADE_SSH=$(cut -d' ' -f1,2 "$KEYS_DIR/hosts/jade.pub")
    echo "🔑 Jade SSH: $JADE_SSH"
fi

if [ -f "$KEYS_DIR/hosts/emy.pub" ]; then
    EMY_SSH=$(cut -d' ' -f1,2 "$KEYS_DIR/hosts/emy.pub")
    echo "🔑 Emy SSH: $EMY_SSH"
fi

if [ -f "$KEYS_DIR/hosts/ruby.pub" ]; then
    RUBY_SSH=$(cut -d' ' -f1,2 "$KEYS_DIR/hosts/ruby.pub")
    echo "🔑 Ruby SSH: $RUBY_SSH"
fi

# Génération du fichier .sops.yaml
echo "📝 Génération du fichier .sops.yaml..."
cat > .sops.yaml << EOF
keys:
  # Clé age maître
  - &admin_age $AGE_PUBLIC_KEY
  
  # Clés SSH des machines
$([ -n "$JADE_SSH" ] && echo "  - &jade_ssh $JADE_SSH")
$([ -n "$EMY_SSH" ] && echo "  - &emy_ssh $EMY_SSH")  
$([ -n "$RUBY_SSH" ] && echo "  - &ruby_ssh $RUBY_SSH")

creation_rules:
  # Secrets communs à tout le cluster
  - path_regex: ceph/cluster\.yaml$
    key_groups:
    - age:
        - *admin_age
$([ -n "$JADE_SSH" ] && echo "      ssh:")
$([ -n "$JADE_SSH" ] && echo "        - *jade_ssh")
$([ -n "$EMY_SSH" ] && echo "        - *emy_ssh")  
$([ -n "$RUBY_SSH" ] && echo "        - *ruby_ssh")

  # Secrets spécifiques aux monitors
  - path_regex: ceph/monitors\.yaml$
    key_groups:
    - age:
        - *admin_age
$([ -n "$JADE_SSH" ] && echo "      ssh:")
$([ -n "$JADE_SSH" ] && echo "        - *jade_ssh")
$([ -n "$EMY_SSH" ] && echo "        - *emy_ssh")
$([ -n "$RUBY_SSH" ] && echo "        - *ruby_ssh")

  # Secrets spécifiques aux managers  
  - path_regex: ceph/managers\.yaml$
    key_groups:
    - age:
        - *admin_age
$([ -n "$JADE_SSH" ] && echo "      ssh:")
$([ -n "$JADE_SSH" ] && echo "        - *jade_ssh")
$([ -n "$EMY_SSH" ] && echo "        - *emy_ssh")
$([ -n "$RUBY_SSH" ] && echo "        - *ruby_ssh")

  # Secrets spécifiques aux OSDs
  - path_regex: ceph/osds\.yaml$
    key_groups:
    - age:
        - *admin_age
$([ -n "$JADE_SSH" ] && echo "      ssh:")
$([ -n "$JADE_SSH" ] && echo "        - *jade_ssh")
$([ -n "$EMY_SSH" ] && echo "        - *emy_ssh")
$([ -n "$RUBY_SSH" ] && echo "        - *ruby_ssh")
EOF

echo "✅ Fichier .sops.yaml généré"
echo ""
echo "🔍 Vérification de la configuration:"
cat .sops.yaml
echo ""
echo "🎉 Configuration sops terminée!"
echo ""
echo "📋 Prochaines étapes:"
echo "1. Vérifiez le contenu de .sops.yaml ci-dessus"
echo "2. Exécutez: /etc/nixos/scripts/init-ceph-secrets.sh"
echo "3. Testez: sops -d /etc/nixos/secrets/ceph/cluster.yaml"
echo ""
echo "💾 Sauvegardez précieusement: $KEYS_DIR/age-keys.txt"

