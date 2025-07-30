{ config, lib, pkgs, ... }:

let
  ageKeyFile = "/var/lib/sops-nix/key.txt";
in
{
  imports = [
    (builtins.fetchTarball {
      url = "https://github.com/Mic92/sops-nix/archive/master.tar.gz";
    } + "/modules/sops/default.nix")
  ];

  # 1. Création de la clé age **avant** que sops-nix ne tente de l’utiliser
  system.activationScripts.generate-age-key = {
    text = ''
      set -euo pipefail
      mkdir -p "$(dirname "${ageKeyFile}")"
      if [[ ! -f "${ageKeyFile}" ]]; then
        ${pkgs.age}/bin/age-keygen -o "${ageKeyFile}"
        chmod 600 "${ageKeyFile}"
        chown root:root "${ageKeyFile}"
      fi
    '';
    deps = [];               # s’exécute très tôt
  };

  # 2. On indique à sops-nix où lire la clé
  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    age.keyFile = ageKeyFile;
  };
}


