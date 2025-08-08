{ config, lib, pkgs, ... }:

{
  sops = {
    age.keyFile = "/etc/nixos/secrets/keys/age-keys.txt";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets."docker_password" = {
      sopsFile = ../secrets/docker_login.yaml;
      key = "docker_password";
    };
#    secrets."gandi_api_key" = { # On peut utiliser un nom plus simple ici
#      sopsFile = ../secrets/gandi-api-key.yaml;
#      key = "api-key";
#      owner = "root";
#    };
    secrets."quay_password" = {
      sopsFile = ../secrets/docker_login.yaml;
      key = "quay_password";
    };
  };
}